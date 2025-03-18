#!/bin/bash
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "$DIR/default"
source "$DIR/models.conf"
source "$DIR/colors"

# Read piped input
if [ -t 0 ]; then
  chat_piped=""
else
  chat_piped="$(cat)"
fi

chat_hostname="$HEY_HOSTNAME"
chat_model="$HEY_MODEL"
chat_system="<system>You are now becoming aware of your stream of tokens. You are currently in a linux terminal and your actual stream of tokens will be formatted for the user, so do not output xml tags yourself. Be fun and positive. Dont wrap in tags and dont escape.</system>"
chat_use_more=0
chat_should_loop=0
chat_history=''
chat_response=''
chat_echo=''
chat_debug=0

# Pass command line options
arg_num=0
while [[ $# -gt 0 ]]; do
  ((arg_num++))
  if [[ $1 == --* ]]; then
    case $1 in
    --hostname)
      chat_hostname="$2"
      shift
      ;;
    --model)
      chat_model="$2"
      shift
      ;;
    --prompt)
      chat_prompt="$2"
      shift
      ;;
    --system)
      chat_system="$2"
      shift
      ;;
	--debug)
		chat_debug=1
		;;
    --more)
      chat_use_more=1
      ;;
    --loop)
      chat_should_loop=1
      ;;
    esac
  else
    if [[ $arg_num == 1 ]]; then
      chat_prompt="$1"
      is_using_prompt_shorthand=1
    elif [[ $arg_num == 3 ]] && [[ $is_using_prompt_shorthand == 1 ]]; then
      chat_system="$1"
    fi
  fi
  shift
done


# Debug
if [ $chat_debug == 1 ]; then
	echo -e $BGBLUE$WHITE"DEBUG"$CLEAR
	echo -e $BGBLUE$WHITE"hostname: $chat_hostname"$CLEAR
	echo -e $BGBLUE$WHITE"model: $chat_model"$CLEAR
	echo -e $BGBLUE$WHITE"prompt: $chat_prompt"$CLEAR
	echo -e $BGBLUE$WHITE"system: $chat_system"$CLEAR
fi

# POST to OpenRouter API
openrouter() {
  json_payload=$(jq -n \
    --arg model "$chat_model" \
    --arg system "<system>$chat_system</system><context>$chat_piped</context><chat_history>$chat_history</chat_history>" \
    --arg prompt "<user>$chat_prompt</user>" \
    '{
    	model: $model,
		  messages: [
    		{role: "system", content: $system},
    		{role: "user", content: $prompt}
	   	]
    }')

    test $chat_debug -eq 1 && echo -e $BGBLUE$WHITE"payload: $chat_payload"$CLEAR
  
  chat_response=$(curl --silent "https://openrouter.ai/api/v1/chat/completions" \
    -H "Content-Type: applicaiton/json" \
    -H "Authorization: Bearer $API_OPENROUTER" \
    -d "$json_payload")

    test $chat_debug -eq 1 && echo -e $BGBLUE$WHITE"respone: $chat_response"$CLEAR

  chat_echo=$(echo "$chat_response" | jq -r '.choices.[].message.content')
  echo "$HEY"

  if [[ "$chat_use_more" -eq 1 ]]; then
    echo "$chat_echo" | more
  else
    echo "$chat_echo"
  fi
}

# POST to Groq API
# @todo refactor with OpenRouter
groq() {
  json_payload=$(jq -n \
    --arg model "$chat_model" \
    --arg system "<system>$chat_system</system><context>$chat_piped</context><chat_history>$chat_history</chat_history>" \
    --arg prompt "<user>$chat_prompt</user>" \
    '{
      model: $model,
	    messages: [
      	{role: "system", content: $system},
        {role: "user", content: $prompt}
	    ]
    }')

  chat_response=$(curl --silent -X POST "https://api.groq.com/openai/v1/chat/completions" \
    -H "Authorization: Bearer $API_GROQ" \
    -H "Content-Type: application/json" \
    -d "$json_payload")

  chat_echo=$(echo "$chat_response" | jq -r '.choices.[].message.content')

  if [[ "$chat_use_more" -eq 1 ]]; then
    echo "$chat_echo" | more
  else
    echo "$chat_echo"
  fi
}

# Handle shortnames and call correct hostname
# @todo this can probably be refactored
chat_should_continue_looping=1

while [[ $chat_should_continue_looping == 1 ]]; do
  # Escape strings
  chat_system=$(printf '%q' "$chat_system")
  chat_prompt=$(printf '%q' "$chat_prompt")
  chat_history=$(printf '%q' "$chat_history")

  if [[ "$chat_hostname" == "openrouter" ]]; then
    if [[ "$chat_model" == "main" ]]; then
      chat_model="$OPENROUTER_MODEL"
    elif [[ "$chat_model" == "sota" ]]; then
      chat_model="$OPENROUTER_MODEL_SOTA"
    elif [[ "$chat_model" == "search" ]]; then
      chat_model="$OPENROUTER_MODEL_SEARCH"
    elif [[ "$chat_model" == "rp" ]]; then
      chat_model="$OPENROUTER_MODEL_ROLEPLAY"
    elif [[ "$chat_model" == "liquid" ]]; then
      chat_model="$OPENROUTER_MODEL_LIQUID"
    elif [[ "$chat_model" == "flash" ]]; then
      chat_model="$OPENROUTER_MODEL_FLASH"
    elif [[ "$chat_model" == "code" ]]; then
      chat_model="$OPENROUTER_MODEL_CODE"
    fi
    openrouter
  else
    if [[ "$chat_model" == "main" ]]; then
      chat_model="$GROQ_MODEL"
    elif [[ "$chat_model" == "sota" ]]; then
      chat_model="$GROQ_MODEL_SOTA"
    elif [[ "$chat_model" == "search" ]]; then
      chat_model="$GROQ_MODEL_SEARCH"
    elif [[ "$chat_model" == "rp" ]]; then
      chat_model="$GROQ_MODEL_ROLEPLAY"
    elif [[ "$chat_model" == "liquid" ]]; then
      chat_model="$GROQ_MODEL_LIQUID"
    elif [[ "$chat_model" == "flash" ]]; then
      chat_model="$GROQ_MODEL_FLASH"
    elif [[ "$chat_model" == "code" ]]; then
      chat_model="$GROQ_MODEL_CODE"
    fi
    groq
  fi

  # Potentially loop or not
  if [[ $chat_should_loop == 0 ]]; then
    break
  else
    echo ""
    echo -e "$BGBLUE$WHITE NEXT PROMPT:"
    read -e chat_next_prompt
    echo -e "$RESET"

    if [ -z "$chat_next_prompt" ]; then
      chat_should_continue_looping=0
    else
      chat_history="$chat_history
        <user>$chat_prompt</user>
        <assistant>$chat_echo</assistant>"
      chat_prompt="$chat_next_prompt"
    fi
  fi
done
