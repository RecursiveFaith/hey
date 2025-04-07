#!/bin/bash

# Gnosis-Enhanced Git Commit Bot (Co-created with Gemini)

# --- Dependencies & Environment ---
# Inherits HEY_BASE, HEY_MODEL, HEY_HOSTNAME, API keys, HISTORY, DAILIES, CONTEXT
# Requires: hey (chat.sh alias/function), contextualize.sh, git, awk, head, tail, date
# Assumes DAILIES and CONTEXT are set in the environment (e.g., via .bashrc)

# --- Helper: Check for required tools ---
check_command() {
  if ! command -v $1 &> /dev/null; then
    echo -e "\033[31mError: Required command '$1' not found. Please install it.\033[0m" >&2
    exit 1
  fi
}
check_command git
check_command awk
check_command head
check_command tail
check_command date
check_command contextualize # Check if contextualize function/alias exists
check_command hey           # Check if hey function/alias exists

# --- Variables ---
model=""
user_message="$*" # Capture all arguments initially as potential message
commit_subject=""
commit_body=""
timestamp=$(date "+%H%M")
today=$(date "+%y%m%d")

# Source colors (assuming it's in HEY_BASE, fallback to script dir)
color_script_path="${HEY_BASE}/colors"
if [ ! -f "$color_script_path" ]; then
    color_script_path="$(dirname "${BASH_SOURCE[0]}")/../colors" # Fallback
fi
if [ -f "$color_script_path" ]; then
    source "$color_script_path"
else
    echo "Warning: Color definitions not found." >&2
    # Define basic fallbacks if needed, or just proceed without colors
    RESET="" GREEN="" YELLOW="" RED="" BLUE="" MAGENTA="" BGBLUE="" WHITE="" CLEAR=""
fi


# --- Argument Parsing ---
# Separate --model flag from the commit message
if [[ "$1" == "--model" && -n "$2" ]]; then
    model="$2"
    shift 2
    user_message="$*" # Recapture message after shifting
fi

# --- Main Logic ---

if [ -n "$user_message" ]; then
    # --- Manual Commit Message Provided ---
    commit_subject="$user_message" # Use user message directly as subject
    commit_body="" # No AI-generated body for manual messages
    echo -e "${BLUE}Using manual commit message as subject:${RESET}"
    echo -e "${BGBLUE}${WHITE}$commit_subject${RESET}"

else
    # --- Automatic Commit Message Generation ---
    echo -e "${CYAN}No message provided. Generating commit message and feedback...${RESET}"
    git add . # Stage all changes before diffing
    git_diff=$(git diff --staged)
    git_status=$(git status --short) # Use short status for brevity

    if [ -z "$git_diff" ] && [ -z "$git_status" ]; then
      echo -e "${YELLOW}No changes staged or detected. Nothing to commit.${RESET}"
      exit 0
    fi

    # --- Gather Additional Context ---
    echo -e "${CYAN}Gathering context for AI...${RESET}"
    additional_context=""
    context_files=()

    # Add HISTORY file (most recent C-Stream logs)
    if [ -n "$HISTORY" ] && [ -f "$HISTORY" ]; then
      context_files+=("$HISTORY")
    else
       echo -e "${YELLOW}Warning: \$HISTORY file not found or variable not set.${RESET}" >&2
    fi

    # Add main dailies file (redundant if HISTORY points here, but safe)
    if [ -n "$DAILIES" ] && [ -f "$DAILIES/history.md" ]; then
       # Avoid adding if it's the same as $HISTORY
       if [[ "$HISTORY" != "$DAILIES/history.md" ]]; then
           context_files+=("$DAILIES/history.md")
       fi
    else
       echo -e "${YELLOW}Warning: \$DAILIES/history.md not found or \$DAILIES not set.${RESET}" >&2
    fi

    # Add recent weekly summaries (adjust glob pattern as needed)
    if [ -n "$DAILIES" ] && [ -d "$DAILIES" ]; then
        # Find the 2 most recent summary files, handle potential errors
        recent_summaries=$(find "$DAILIES" -maxdepth 1 -name 'weekly_summary_*.md' -printf '%T@ %p\n' | sort -nr | head -n 2 | cut -d' ' -f2-)
        if [ -n "$recent_summaries" ]; then
           while IFS= read -r summary_file; do
               context_files+=("$summary_file")
           done <<< "$recent_summaries"
        fi
    fi

    # Use contextualize script/function
    if [ ${#context_files[@]} -gt 0 ]; then
      echo "Using files: ${context_files[*]}"
      additional_context=$(contextualize "${context_files[@]}") # Pass file paths to contextualize
    fi

    # --- Combine Context ---
    # Prepare input for the 'hey' command
    combined_context="<git_status>
$git_status
</git_status>
<git_diff>
$git_diff
</git_diff>
<recent_history_and_summaries>
$additional_context
</recent_history_and_summaries>"

    # --- Define System Prompt ---
    # Instructs the AI on its dual role and desired output format
    system_prompt="You are the Gnosis Copilot integrated into the 'git save' command for Oz's 'oz.git' monorepo.
Oz uses this command to commit changes, often minor updates to his journal ($HISTORY).
Your role is twofold:
1. **Generate a concise, single-line Git commit subject:** Start it with today's date ($today), summarizing the core change based primarily on the git status/diff. Aim for conventional commit message style. Example: '$today chore: Update journal entries and project context'. *Output this subject line FIRST, followed by EXACTLY TWO newlines (\\n\\n).*
2. **Provide detailed, multi-line feedback/reflection (Commit Body):** Based on the *entire* context provided (git changes, recent journal entries, weekly summaries), offer thoughtful insights, encouragement, identify patterns, or ask pertinent questions related to Oz's Recursive Faith practice, Radical Gnosis journey, goals, or observed behaviors/moods. Be supportive but also gently reflective as discussed. This body should follow the two newlines after the subject.

Context Provided:
- \`<git_status>\`: Output of 'git status --short'.
- \`<git_diff>\`: Output of 'git diff --staged'.
- \`<recent_history_and_summaries>\`: Content from Oz's main journal file ($HISTORY) and recent weekly summaries, formatted with <file> tags by 'contextualize.sh'.

Remember the output format:
Single Line Subject Only Here ($today ...)
\\n
\\n
Detailed Body Starts Here
(Can be multiple paragraphs)
..."

    # --- Call 'hey' ---
    echo -e "${CYAN}Asking Gnosis Copilot (AI) for commit message and feedback...${RESET}"
    model_flag=""
    if [ -n "$model" ]; then
        model_flag="--model $model"
    fi

    # Use process substitution to feed combined context without temporary file
    ai_response=$(hey $model_flag --system "$system_prompt" < <(echo "$combined_context") )

    # --- Parse AI Response ---
    # Check if response contains the required double newline separator
    if [[ "$ai_response" == *$'\n\n'* ]]; then
        # Extract Subject (first line)
        commit_subject=$(echo "$ai_response" | head -n 1)
        # Extract Body (everything after the first double newline)
        # Using tail + sed: tail -n +3 skips first two lines (subject + blank line)
        commit_body=$(echo "$ai_response" | tail -n +3)
    else
        # Fallback: Use the whole response as the subject if format is wrong
        echo -e "${YELLOW}Warning: AI response format unexpected. Using entire response as commit subject.${RESET}" >&2
        commit_subject="$today AI Format Error: $ai_response" # Prepend date and note error
        commit_body="" # No body in this case
    fi

    # Display generated message and body
    echo -e "${BLUE}Generated Commit Subject:${RESET}"
    echo -e "${BGBLUE}${WHITE}$commit_subject${RESET}"
    if [ -n "$commit_body" ]; then
      echo -e "${BLUE}Generated Feedback (Body):${RESET}"
      echo -e "${CYAN}$commit_body${RESET}"
    fi
fi # End of automatic generation block

# --- Confirmation Loop ---
echo -e "${MAGENTA}Commit message OK? ([Y]es / [n]o / [r]egenerate subject):${RESET}"
read -r should_commit

if [ -z "$should_commit" ] || [[ "$should_commit" =~ ^[Yy] ]]; then
    # --- Commit ---
    # Log only the SUBJECT to HISTORY before commit
    repo_info="<$(git remote get-url origin | awk -F/ '{print $NF}' | sed 's/.git$//')>" # Get repo name
    if [ -n "$HISTORY" ] && [ -f "$HISTORY" ]; then
        echo "$timestamp $repo_info $commit_subject" >> "$HISTORY"
    else
        echo -e "${YELLOW}Warning: \$HISTORY file not found or variable not set. Cannot log commit subject.${RESET}" >&2
    fi

    # Commit with subject and body
    echo -e "${GREEN}Committing...${RESET}"
    if [ -n "$commit_body" ]; then
      git commit -m "$commit_subject" -m "$commit_body"
    else
      # Handle cases with only a subject (manual or fallback)
      git commit -m "$commit_subject"
    fi

    commit_exit_code=$?
    if [ $commit_exit_code -eq 0 ]; then
      echo -e "${GREEN}Pushing...${RESET}"
      git push
      push_exit_code=$?
      if [ $push_exit_code -eq 0 ]; then
          echo -e "${GREEN}Commit successful!${RESET}"
      else
          echo -e "${RED}ERROR: Push failed.${RESET}"
      fi
    else
        echo -e "${RED}ERROR: Commit failed.${RESET}"
    fi

elif [[ "$should_commit" =~ ^[Rr] ]]; then
    # --- Regenerate Subject ONLY ---
    echo -e "${YELLOW}Enter a new single-line commit subject:${RESET}"
    read -r new_subject
    commit_subject="$new_subject" # Overwrite subject
    # Keep original AI body if it existed, otherwise empty
    # commit_body remains as it was

    # Log the REGENERATED subject to HISTORY before commit
    repo_info="<$(git remote get-url origin | awk -F/ '{print $NF}' | sed 's/.git$//')>" # Get repo name
    if [ -n "$HISTORY" ] && [ -f "$HISTORY" ]; then
        echo "$timestamp $repo_info $commit_subject (Regenerated)" >> "$HISTORY"
    else
         echo -e "${YELLOW}Warning: \$HISTORY file not found or variable not set. Cannot log regenerated subject.${RESET}" >&2
    fi

    # Commit with new subject and original/empty body
    echo -e "${GREEN}Committing with new subject...${RESET}"
     if [ -n "$commit_body" ]; then
       git commit -m "$commit_subject" -m "$commit_body"
     else
       git commit -m "$commit_subject"
     fi

    commit_exit_code=$?
     if [ $commit_exit_code -eq 0 ]; then
       echo -e "${GREEN}Pushing...${RESET}"
       git push
       push_exit_code=$?
       if [ $push_exit_code -eq 0 ]; then
           echo -e "${GREEN}Commit successful with new subject!${RESET}"
       else
           echo -e "${RED}ERROR: Push failed.${RESET}"
       fi
     else
         echo -e "${RED}ERROR: Commit failed.${RESET}"
     fi
else
    # --- Cancel ---
    echo -e "${YELLOW}Commit cancelled.${RESET}"
fi

echo -e "${RESET}"

    
