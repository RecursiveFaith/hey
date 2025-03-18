#!/bin/bash
message="$@"
timestamp=$(date "+%H%M")
today=$(date "+%y%m%d")

# Set the HEY_GIT directory
# @TODO too specific to me, maybe remove?
logfile="$HEY_GIT/$today.md"

# If no message autocommit
if [ -z "$message" ]; then
    git add .
    message=$(git status; git diff --staged)
    message=$(echo "$message" | bash $chat "summarize git changes as a single line commit message. Dont wrap in quotes, add markup...just a single line. Do not acknowledge. Just start the line with todays date and a space: $today " | tr -d '\n')
    echo -e $BGBLUE"$message"$CLEAR
fi

# Ask if should commit
echo -e $MAGENTA"Should the message be committed ([Y]es / [n]o / [r]egenerate)?"$CLEAR
read -r should_commit

if [ -z "$should_commit" ] || [[ "$should_commit" =~ ^[Yy] ]]; then
    # Log the file AFTER confirmation but BEFORE commit
    repo=$(git remote get-url origin | awk -F: '{print $2}')
    if [ -f "$logfile" ]; then
        echo "" >> "$logfile"
        echo "$timestamp <$repo> $message" >> "$logfile"
    else
        echo -e $RED"TODAYS DAILY LOG DOES NOT EXIST YET;\n$GREEN However, COMMIT SUCCESSFUL. $YELLOW MESSAGE ADDED TO $TEAL xsel -ib $YELLOW INSTEAD $RESET"
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
    if [ -f "$logfile" ]; then
        echo "$timestamp <$repo> $message" >> "$logfile"
    else
        echo "$timestamp <$repo> $message" | xsel -ib
    fi
    
    git commit -m "$message"
    git push
    echo -e "$GREEN Commit successful with new message! $RESET"
else
    echo -e "$YELLOW Commit cancelled. $RESET"
fi
