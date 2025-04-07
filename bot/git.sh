#!/bin/bash

# Gnosis-Enhanced Git Commit Bot (Co-created with Gemini) - v3 (Less Verbose & Commit Fix)

# --- Dependencies & Environment ---
# Inherits HEY_BASE, HEY_MODEL, HEY_HOSTNAME, API keys, HISTORY, DAILIES, CONTEXT
# Requires: hey (chat.sh alias/function), contextualize.sh, git, awk, head, tail, date, grep, sed
# Assumes DAILIES and CONTEXT are set in the environment (e.g., via .bashrc)

# --- Helper: Check for required tools ---
check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo -e "\033[31mError: Required command '$1' not found. Please install it.\033[0m" >&2
    exit 1
  fi
}
check_command git
check_command awk
check_command head
check_command tail
check_command date
check_command grep
check_command sed
check_command context # Check if contextualize function/alias exists
check_command hey      # Check if hey function/alias exists

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
    # Try relative path from script location as fallback
    script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    color_script_path="${script_dir}/../colors" # Assuming colors is one level up
fi

if [ -f "$color_script_path" ]; then
    # shellcheck source=../colors
    source "$color_script_path"
else
    echo "Warning: Color definitions not found at '$color_script_path' or '$HEY_BASE/colors'." >&2
    # Define basic fallbacks if needed, or just proceed without colors
    RESET="" GREEN="" YELLOW="" RED="" BLUE="" MAGENTA="" CYAN="" BGBLUE="" WHITE="" CLEAR=""
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
    # Ensure changes are staged for manual messages too
    echo -e "${CYAN}Staging all changes...${RESET}"
    git add -A # Stage all changes (new, modified, deleted)

else
    # --- Automatic Commit Message Generation ---
    # echo -e "${CYAN}No message provided. Generating commit message and feedback...${RESET}" # Verbose
    # Use git add -A to stage ALL changes including deletions relative to current dir
    git add -A
    git_diff=$(git diff --staged)
    git_status=$(git status --short) # Use short status for brevity

    if [ -z "$git_diff" ] && [ -z "$git_status" ]; then
      echo -e "${YELLOW}No changes staged or detected. Nothing to commit.${RESET}"
      exit 0
    fi

    # --- Gather Additional Context ---
    # echo -e "${CYAN}Gathering context for AI...${RESET}" # Verbose
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
        mapfile -t recent_summaries < <(find "$DAILIES" -maxdepth 1 -name 'weekly_summary_*.md' -printf '%T@ %p\0' | sort -znr | head -z -n 2 | xargs -0 -I {} cut -d' ' -f2-)
        if [ ${#recent_summaries[@]} -gt 0 ]; then
            for summary_file in "${recent_summaries[@]}"; do
                 if [[ -f "$summary_file" ]]; then
                     context_files+=("$summary_file")
                 fi
            done
        fi
    fi

    # Use contextualize script/function
    if [ ${#context_files[@]} -gt 0 ]; then
      # echo "Using files for context: ${context_files[*]}" # Verbose
      additional_context=$(context "${context_files[@]}")
    else
        echo -e "${YELLOW}Warning: No context files found to pass to contextualize script.${RESET}" >&2
    fi

    # --- Combine Context ---
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
    system_prompt="You are the Gnosis Copilot integrated into the 'git save' command for Oz's 'oz.git' monorepo.
Oz uses this command to commit changes, often minor updates to his journal ($HISTORY).
Your role is twofold:
1. **Generate a concise, single-line Git commit subject:** Start it with today's date ($today), summarizing the core change based primarily on the git status/diff. Aim for conventional commit message style. Example: '$today chore: Update journal entries and project context'. *Output this subject line FIRST, followed by EXACTLY ONE blank line (a single newline character creating the blank line), then the body.*
2. **Provide detailed, multi-line feedback/reflection (Commit Body):** Based on the *entire* context provided (git changes, recent journal entries, weekly summaries), offer thoughtful insights, encouragement, identify patterns, or ask pertinent questions related to Oz's Recursive Faith practice, Radical Gnosis journey, goals, or observed behaviors/moods. Be supportive but also gently reflective as discussed. This body should follow the single blank line after the subject.

Context Provided:
- \`<git_status>\`: Output of 'git status --short'.
- \`<git_diff>\`: Output of 'git diff --staged'.
- \`<recent_history_and_summaries>\`: Content from Oz's main journal file ($HISTORY) and recent weekly summaries, formatted with <file> tags by 'contextualize.sh'.

Remember the output format:
Single Line Subject Only Here ($today ...)
<-- Exactly one blank line here -->
Detailed Body Starts Here
(Can be multiple paragraphs)
..."

    # --- Call 'hey' ---
    # echo -e "${CYAN}Asking Gnosis Copilot (AI) for commit message and feedback...${RESET}" # Verbose
    model_flag=""
    if [ -n "$model" ]; then
        model_flag="--model $model"
    fi

    ai_response=$(hey $model_flag --system "$system_prompt" < <(printf "%s" "$combined_context") )

    # --- Parse AI Response ---
    # --- Raw AI Response For Debugging (Commented Out By Default) ---
    # echo -e "${BLUE}--- Raw AI Response Start ---${RESET}"
    # printf "%s\n" "$ai_response" # Use printf for safer output
    # echo -e "${BLUE}--- Raw AI Response End ---${RESET}"
    # --- End Raw AI Response ---

    # Extract potential Subject (first non-empty line) and trim whitespace
    commit_subject=$(echo "$ai_response" | awk 'NF > 0 {print; exit}' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

    # Find the line number of the *first* blank line AFTER the potential subject
    subject_line_num=$(echo "$ai_response" | grep -n -F -m 1 "$commit_subject" | head -n 1 | cut -d: -f1)

    if [[ -z "$subject_line_num" ]]; then
         if [[ -n "$commit_subject" ]]; then
             subject_line_num=$(echo "$ai_response" | grep -n -m 1 '[^[:space:]]' | head -n 1 | cut -d: -f1)
         else
             subject_line_num=0
         fi
    fi

    separator_line_num=0
    if [[ "$subject_line_num" -gt 0 ]]; then
        separator_line_num=$(echo "$ai_response" | tail -n +$((subject_line_num + 1)) | grep -n -m 1 -e '^[[:space:]]*$' | head -n 1 | cut -d: -f1)
    fi

    if [[ "$separator_line_num" -gt 0 ]]; then
        actual_separator_line=$((subject_line_num + separator_line_num))
        commit_body=$(echo "$ai_response" | tail -n +$((actual_separator_line + 1)) | sed -e '/./,$!d' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    elif [[ -n "$commit_subject" ]]; then
        body_candidate=$(echo "$ai_response" | tail -n +$((subject_line_num + 1)) )
        if [[ -n "$body_candidate" && "$(echo "$body_candidate" | awk 'NF > 0')" ]]; then
            # echo -e "${YELLOW}Warning: AI response might be missing the blank line separator. Assuming content after first line is body.${RESET}" # Verbose Warning
            commit_body=$(echo "$body_candidate" | sed -e '/./,$!d' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        else
            commit_body=""
        fi
    else
        echo -e "${RED}Error: Could not parse valid subject from AI response. Using fallback.${RESET}" >&2
        commit_subject="$today AI Parse Error: Check logs"
        commit_body=$(echo "$ai_response" | sed -e '/./,$!d' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    fi

    if [ -z "$commit_subject" ]; then
        echo -e "${YELLOW}Warning: Parsed commit subject is empty. Using fallback.${RESET}" >&2
        commit_subject="$today AI Fallback: Empty Subject Parsed"
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
if git symbolic-ref -q HEAD > /dev/null; then
    prompt_message="${MAGENTA}Commit message OK? ([Y]es / [n]o / [r]egenerate subject):${RESET}"
else
    current_commit=$(git rev-parse --short HEAD)
    prompt_message="${YELLOW}Warning: HEAD is detached at $current_commit.${RESET}\n${MAGENTA}Commit message OK? ([Y]es / [n]o / [r]egenerate subject):${RESET}"
fi
echo -e "$prompt_message"
read -r should_commit

current_branch_or_head=$(git symbolic-ref --short -q HEAD || echo "HEAD")

if [ -z "$should_commit" ] || [[ "$should_commit" =~ ^[Yy] ]]; then
    # --- Commit ---
    repo_info="<$(git remote get-url origin | awk -F/ '{print $NF}' | sed 's/\.git$//')>"
    if [ -n "$HISTORY" ] && [ -f "$HISTORY" ]; then
        echo "$timestamp $repo_info $commit_subject" >> "$HISTORY"
    else
        echo -e "${YELLOW}Warning: \$HISTORY file not found or variable not set. Cannot log commit subject.${RESET}" >&2
    fi

    echo -e "${GREEN}Committing...${RESET}"
    if [ -n "$commit_body" ]; then
      git commit -m "$commit_subject" -m "$commit_body"
    else
      git commit -m "$commit_subject"
    fi

    commit_exit_code=$?
    if [ $commit_exit_code -eq 0 ]; then
        if [[ "$current_branch_or_head" == "HEAD" ]]; then
             echo -e "${YELLOW}Push skipped: Cannot push from detached HEAD. Commit created.${RESET}"
             echo -e "${YELLOW}To push, checkout a branch and merge/cherry-pick, or push directly: git push origin HEAD:<remote-branch-name>${RESET}"
        else
            echo -e "${GREEN}Pushing to origin $current_branch_or_head...${RESET}"
            git push origin "$current_branch_or_head"
            push_exit_code=$?
            if [ $push_exit_code -eq 0 ]; then
                echo -e "${GREEN}Commit successful!${RESET}"
            else
                echo -e "${RED}ERROR: Push failed. Commit was created locally.${RESET}"
            fi
        fi
    else
        echo -e "${RED}ERROR: Commit failed.${RESET}"
        # Add hint about staging if commit failed
        echo -e "${RED}Check if changes were staged correctly.${RESET}"
    fi

elif [[ "$should_commit" =~ ^[Rr] ]]; then
    # --- Regenerate Subject ONLY ---
    echo -e "${YELLOW}Enter a new single-line commit subject:${RESET}"
    read -r new_subject
    if [[ -z "$new_subject" && "$commit_subject" != *"AI Fallback"* && "$commit_subject" != *"AI Parse Error"* ]]; then
        echo -e "${YELLOW}Keeping original subject: $commit_subject${RESET}"
    elif [[ -n "$new_subject" ]]; then
         commit_subject="$new_subject"
    else
         echo -e "${YELLOW}No new subject entered, keeping: $commit_subject${RESET}"
    fi

    repo_info="<$(git remote get-url origin | awk -F/ '{print $NF}' | sed 's/\.git$//')>"
    if [ -n "$HISTORY" ] && [ -f "$HISTORY" ]; then
        echo "$timestamp $repo_info $commit_subject (Regenerated)" >> "$HISTORY"
    else
        echo -e "${YELLOW}Warning: \$HISTORY file not found or variable not set. Cannot log regenerated subject.${RESET}" >&2
    fi

    echo -e "${GREEN}Committing with new subject...${RESET}"
    if [ -n "$commit_body" ]; then
      git commit -m "$commit_subject" -m "$commit_body"
    else
      git commit -m "$commit_subject"
    fi

    commit_exit_code=$?
    if [ $commit_exit_code -eq 0 ]; then
         if [[ "$current_branch_or_head" == "HEAD" ]]; then
             echo -e "${YELLOW}Push skipped: Cannot push from detached HEAD. Commit created.${RESET}"
             echo -e "${YELLOW}To push, checkout a branch and merge/cherry-pick, or push directly: git push origin HEAD:<remote-branch-name>${RESET}"
         else
            echo -e "${GREEN}Pushing to origin $current_branch_or_head...${RESET}"
            git push origin "$current_branch_or_head"
            push_exit_code=$?
            if [ $push_exit_code -eq 0 ]; then
                echo -e "${GREEN}Commit successful with new subject!${RESET}"
            else
                echo -e "${RED}ERROR: Push failed. Commit was created locally.${RESET}"
            fi
        fi
    else
        echo -e "${RED}ERROR: Commit failed.${RESET}"
        echo -e "${RED}Check if changes were staged correctly.${RESET}"
    fi
else
    # --- Cancel ---
    echo -e "${YELLOW}Commit cancelled.${RESET}"
    echo -e "${YELLOW}Note: Changes were staged with 'git add -A'. Use 'git reset' to unstage if needed.${RESET}"
fi

echo -e "${RESET}"

