#!/bin/bash

# === git_gnosis.sh (v4 - Corrected Summary Path & Minor Fixes) ===
# Enhanced git commit helper piping necessary context directly into 'hey'.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
# Assume 'hey' alias OR HEY_BASE env var is correctly set in .bashrc
# Ensure necessary env vars like HISTORY, DAILIES, CONTEXT are set in .bashrc

# --- Color Codes ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'; BGBLUE='\033[44m'; WHITE='\033[97m'; RESET='\033[0m'

# --- Argument Parsing ---
model=""
manual_message="$*"
if [[ "$1" == "--model" && -n "$2" ]]; then
    model="$2"; shift 2; manual_message="$*"
fi

timestamp=$(date "+%H%M"); today=$(date "+%y%m%d"); export PATH=$PATH

# --- Main Logic ---

if [ -n "$manual_message" ]; then
    # --- Manual Commit ---
    echo -e "${MAGENTA}Using manual commit message.${RESET}"
    commit_summary="$today $manual_message"
    # Set a default feedback for manual case if needed later
    # verbose_feedback="Manual message provided."

else
    # --- Auto-generate Commit + Feedback ---
    echo -e "${CYAN}Gathering context for AI analysis...${RESET}"
    # It's safer to stage changes AFTER getting the diff of only currently staged items
    # Or stage all first, then get diff --staged. Staging first for simplicity here.
    git add . # Stage all changes

    # --- Prepare Context Data ---
    # Get Git Status & Diff (now uses --staged)
    git_changes=$( (git status --short; echo "---DIFF---"; git diff --staged) ) # Get diff of already staged changes

    # Get Recent History, Backlog, Structured Summaries
    context_files_content=""
    history_file_path="$HISTORY"
    backlog_file_path="$DAILIES/backlog.md"
    # --- CORRECTED SUMMARY PATH ---
    # Use $CONTEXT env var and the correct subdirectory
    summary_dir="$CONTEXT/structured"
    summary_pattern="$summary_dir/*-structured.md"
    # --- END CORRECTION ---


    if [ -z "$history_file_path" ] || [ ! -f "$history_file_path" ]; then
       echo -e "${YELLOW}Warning: \$HISTORY file ('$history_file_path') not found or env var not set.${RESET}"
    else
       # Ensure HISTORY exists before trying to tail it
       context_files_content+="$(echo -e '\n---HISTORY START---\n'; tail -n 50 "$history_file_path"; echo -e '\n---HISTORY END---\n')"
    fi

    if [ -z "$DAILIES" ] || [ ! -f "$backlog_file_path" ]; then
        echo -e "${YELLOW}Warning: Backlog '$backlog_file_path' not found or \$DAILIES env var not set.${RESET}"
    else
         # Ensure backlog exists before trying to cat it
        context_files_content+="$(echo -e '\n---BACKLOG START---\n'; cat "$backlog_file_path"; echo -e '\n---BACKLOG END---\n')"
    fi

    # Check if the summary directory exists before trying to list files
    if [ -z "$CONTEXT" ] || [ ! -d "$summary_dir" ]; then
        echo -e "${YELLOW}Warning: Summary directory '$summary_dir' not found or \$CONTEXT env var not set.${RESET}"
        latest_summary="" # Ensure latest_summary is empty if dir doesn't exist
    else
        # Find the latest structured summary file using the pattern
        # Use find for more robust handling of filenames with spaces/special chars? ls should be okay here.
        latest_summary=$(ls -t $summary_pattern 2>/dev/null | head -n 1)
    fi

    # Check if a file was found and exists before trying to cat it
    if [ -n "$latest_summary" ] && [ -f "$latest_summary" ]; then
         context_files_content+="$(echo -e '\n---LATEST SUMMARY START---\n'; cat "$latest_summary"; echo -e '\n---LATEST SUMMARY END---\n')"
    else
        echo -e "${YELLOW}Warning: No structured summary matching '$summary_pattern' found.${RESET}"
    fi
    # --- End Prepare Context Data ---

    echo -e "${CYAN}Requesting AI commit message and feedback...${RESET}"
    model_flag=""
    if [ -n "$model" ]; then model_flag="--model $model"; fi

    # --- Define System Prompt (Same as v2/v3) ---
    system_prompt="You are my Gnosis Copilot, embedded in my git commit workflow. Context provided includes: recent journal entries (\$HISTORY), the project backlog, the latest structured weekly summary, and the current git changes. Your task is TWO-FOLD:
1. Generate a concise, single-line git commit message (max 72 chars) summarizing the *technical changes* only. Start it ONLY with today's date ('$today') followed by a space.
2. AFTER the commit message, add the exact delimiter '---GNOSIS_FEEDBACK_START---'.
3. AFTER the delimiter, provide brief, insightful feedback (2-4 sentences) based on the *entire context* (journal, backlog, summaries, changes). Acknowledge current state/goals. Offer encouragement or gentle observations. Connect changes to Recursive Faith themes if applicable.
Respond directly, no filler."

    # --- Execute HEY by piping combined context ---
    # Add error checking for the 'hey' command itself
    ai_response=$( (echo "$git_changes"; echo "$context_files_content") | hey "$model_flag" --system "$system_prompt" --prompt "Analyze context and generate commit message + feedback." )
    hey_exit_code=$? # Capture exit code of the hey command

    if [ $hey_exit_code -ne 0 ] || [ -z "$ai_response" ]; then
        echo -e "${RED}Error: Failed to get response from AI ('hey' command failed or returned empty).${RESET}"
        # Exit or fallback to manual commit? Exiting for now.
        exit 1
    fi

    # --- Parse Response ---
    commit_summary=$(echo "$ai_response" | awk -F'---GNOSIS_FEEDBACK_START---' '{print $1}' | head -n 1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    verbose_feedback=$(echo "$ai_response" | awk -F'---GNOSIS_FEEDBACK_START---' '{print $2}' | sed 's/^[[:space:]]*//')

    # --- Fallback if parsing fails (e.g., delimiter missing) ---
     if [ -z "$commit_summary" ] && [ -n "$ai_response" ]; then
        echo -e "${YELLOW}Warning: Could not parse AI response structure. Using full response as summary.${RESET}"
        commit_summary="$today AI Response Error: $ai_response" # Use full response as fallback summary
        commit_summary="${commit_summary:0:150}" # Truncate long fallback
        verbose_feedback="AI response parsing failed. See commit message."
     elif [ -z "$commit_summary" ]; then
         echo -e "${RED}Error: Failed to generate commit summary.${RESET}"
         exit 1
     fi


    # --- Display ---
    echo -e "${CYAN}---------------------------------${RESET}"
    echo -e "${GREEN}Proposed Commit:${RESET} ${BGBLUE}${WHITE}${commit_summary}${RESET}"
    echo -e "${CYAN}---------------------------------${RESET}"
    echo -e "${MAGENTA}Gnosis Copilot Feedback:${RESET}"
    echo -e "${verbose_feedback}" # Display feedback even if parsing failed
    echo -e "${CYAN}---------------------------------${RESET}"
fi

# --- Confirmation and Commit Logic (SAME AS PREVIOUS VERSION) ---
echo -e "${MAGENTA}Commit this message? ([Y]es / [n]o / [r]egenerate / [e]dit)${RESET}"
read -r should_commit

# (Rest of the script: Confirmation Y/N/R/E and commit/push logic remains unchanged from v3)
# ...
if [ -z "$should_commit" ] || [[ "$should_commit" =~ ^[Yy]$ ]]; then
    repo_name=$(basename `git rev-parse --show-toplevel`)
    log_entry="$timestamp <$repo_name> $commit_summary"
    history_file_path="$HISTORY"
    if [ -z "$history_file_path" ] || [ ! -f "$history_file_path" ]; then echo -e "${YELLOW}Warning: \$HISTORY missing, logging to clipboard.${RESET}"; echo "$log_entry" | xsel -ib; else echo "$log_entry" >> "$history_file_path"; fi
    # git add . # Already added
    git commit -m "$commit_summary"; git push origin HEAD
    echo -e "${GREEN}Commit successful!${RESET}"

elif [[ "$should_commit" =~ ^[Ee]$ ]]; then
    echo -e "${YELLOW}Current message: ${commit_summary}${RESET}"; echo -e "${YELLOW}Enter new/edited commit message:${RESET}"
    read -e -i "$commit_summary" edited_message; commit_summary="$edited_message"
    repo_name=$(basename `git rev-parse --show-toplevel`)
    log_entry="$timestamp <$repo_name> $commit_summary"
    history_file_path="$HISTORY"
    if [ -z "$history_file_path" ] || [ ! -f "$history_file_path" ]; then echo -e "${YELLOW}Warning: \$HISTORY missing, logging to clipboard.${RESET}"; echo "$log_entry" | xsel -ib; else echo "$log_entry" >> "$history_file_path"; fi
    # git add .
    git commit -m "$commit_summary"; git push origin HEAD
    echo -e "${GREEN}Commit successful with edited message!${RESET}"

elif [[ "$should_commit" =~ ^[Rr]$ ]]; then
    echo -e "${YELLOW}Regeneration requested. Please enter commit message manually:${RESET}"; read -r new_manual_message
    commit_summary="$today $new_manual_message" # Add date prefix
    repo_name=$(basename `git rev-parse --show-toplevel`)
    log_entry="$timestamp <$repo_name> $commit_summary"
    history_file_path="$HISTORY"
    if [ -z "$history_file_path" ] || [ ! -f "$history_file_path" ]; then echo -e "${YELLOW}Warning: \$HISTORY missing, logging to clipboard.${RESET}"; echo "$log_entry" | xsel -ib; else echo "$log_entry" >> "$history_file_path"; fi
    # git add .
    git commit -m "$commit_summary"; git push origin HEAD
    echo -e "${GREEN}Commit successful with regenerated (manual) message!${RESET}"
else
    echo -e "${YELLOW}Commit cancelled.${RESET}"
    # git reset HEAD --quiet # Optional: unstage changes if needed
fi

echo -e $RESET

    
