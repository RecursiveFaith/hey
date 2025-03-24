#!/bin/bash

# Check for --model flag
model=""
if [[ "$1" == "--model" && -n "$2" ]]; then
    model="$2"
    shift 2  # Remove --model and its value from arguments
fi

message="$@"
timestamp=$(date "+%H%M")
today=$(date "+%y%m%d")
export PATH=$PATH

# If no message autocommit
if [ -z "$message" ]; then
    git add .
    message=$(git status; git diff --staged)

    # Add model flag if specified
    model_flag=""
    if [ -n "$model" ]; then
        model_flag="--model $model"
    fi

    message=$(echo "$message" | bash $chat $model_flag --prompt "summarize git changes as a single line commit message. Dont wrap in quotes, add markup...just a single line. Do not acknowledge. Just start the line with todays date and a space: $today " | tr -d '\n')
    echo -e $BGBLUE"$message"$CLEAR
fi

# Ask if should commit
echo -e $MAGENTA"Should the message be committed ([Y]es / [n]o / [r]egenerate)?"$CLEAR
read -r should_commit

if [ -z "$should_commit" ] || [[ "$should_commit" =~ ^[Yy] ]]; then
    # Log to DIARY_HISTORY AFTER confirmation but BEFORE commit
    repo=$(git remote get-url origin | awk -F: '{print $2}')
    if [ -f "$DIARY_HISTORY" ]; then
        echo "$timestamp <$repo> $message" >> "$DIARY_HISTORY"
    else
        echo -e $RED"DIARY_HISTORY FILE DOES NOT EXIST YET;\n$GREEN However, COMMIT SUCCESSFUL. $YELLOW MESSAGE ADDED TO $TEAL xsel -ib $YELLOW INSTEAD $RESET"
        echo "$timestamp <$repo> $message" | xsel -ib
    fi
    
    # Now do the commit
    git add .
    git commit -m "$message"
    git push
    echo -e "$GREEN Commit successful! $RESET"
elif [[ "$should_commit" =~ ^[Rr] ]]; then
    echo -e "$YELLOW Please enter a new commit message: $RESET"
    read -r new_message
    message="$new_message"
    
    # Log the regenerated message
    repo=$(git remote get-url origin | awk -F: '{print $2}')
    if [ -f "$DIARY_HISTORY" ]; then
        echo "$timestamp <$repo> $message" >> "$DIARY_HISTORY"
    else
        echo "$timestamp <$repo> $message" | xsel -ib
    fi
    
    git commit -m "$message"
    git push
    echo -e "$GREEN Commit successful with new message! $RESET"
else
    echo -e "$YELLOW Commit cancelled. $RESET"
fi

echo -e $RESET
