#!/bin/bash
# --- Configuration ---
# Get the history file path (using $HISTORY environment variable as default if no argument is passed)
HISTORY_FILE="${1:-$HISTORY}"

# Define the output file name and path (inside $DAILIES)
# Ensure DAILIES variable is available (it should be if sourced from .bashrc)
if [ -z "$DAILIES" ]; then
  echo "Error: DAILIES environment variable is not set. Cannot determine output directory."
  exit 1
fi
OUTPUT_FILENAME="weekly_summary_$(date +%y%m%d).md"
OUTPUT_FILE="$DAILIES/$OUTPUT_FILENAME"

# No need to define 'hey' or 'context' here, they are inherited from the environment (.bashrc)

# Check if HISTORY_FILE is set and exists
if [ -z "$HISTORY_FILE" ]; then
  echo "Error: HISTORY environment variable is not set and no history file path provided as an argument."
  exit 1
elif [ ! -f "$HISTORY_FILE" ]; then
  echo "Error: History file '$HISTORY_FILE' not found."
  exit 1
fi

# Clear the output file if it exists
> "$OUTPUT_FILE"

echo "Generating Weekly Summary from $HISTORY_FILE into $OUTPUT_FILE..."

# --- Helper Function for Appending ---
# Adds a section header and the output of a hey command to the summary file
append_section() {
    local title="$1"
    local command_output="$2"

    echo "" >> "$OUTPUT_FILE" # Add spacing
    echo "## $title" >> "$OUTPUT_FILE"
    echo "" >> "$OUTPUT_FILE"
    # Use the inherited 'hey' and 'context' functions directly
    echo "$command_output" >> "$OUTPUT_FILE"
    echo "---" >> "$OUTPUT_FILE" # Separator
}

# --- Extraction Commands ---

echo "# Weekly Summary for Period Ending $(date +%Y-%m-%d)" >> "$OUTPUT_FILE"
echo "*Generated on $(date)*" >> "$OUTPUT_FILE"

# 1. Sleep Overview (CSV)
echo "Extracting Sleep Data..."
# Use inherited context and hey functions
sleep_data=$(context "$HISTORY_FILE" | hey 'Extract all lines starting with "Sleep" into a CSV format with headers: Date, Sleep Score, Sleep Start, Sleep End. Use the date from the ## heading preceding the Sleep line as the Date column value.')
append_section "Sleep Overview" "$sleep_data"

# 2. Dream Logs
echo "Extracting Dream Logs..."
dream_logs=$(context "$HISTORY_FILE" | hey 'Extract all detailed dream descriptions. Include the date from the ## heading before each dream. Format as a list with date followed by dream summary.')
append_section "Dream Logs" "$dream_logs"

# 3. Substance Use Overview
echo "Extracting Substance Use Data..."
substance_data=$(context "$HISTORY_FILE" | hey 'Extract all mentions of substance use (edibles, alcohol, beer, weed, Seroquel, propranolol). Include the date, substance, dosage/amount if mentioned, time if mentioned, and any subjective effect rating (like [1-10] or 😍). Format clearly for each instance.')
append_section "Substance Use" "$substance_data"

# 4. Weight Trend (CSV)
echo "Extracting Weight Data..."
weight_data=$(context "$HISTORY_FILE" | hey 'Extract all lines starting with "Weight" into a CSV format with headers: Date, Weight. Use the date from the ## heading preceding the Weight line.')
append_section "Weight Trend" "$weight_data"

# 5. Financial Summary (Income/Expenses)
echo "Extracting Financial Data..."
finance_data=$(context "$HISTORY_FILE" | hey 'Extract all lines under "## Money" headings. Summarize total income (positive numbers) and total spending (negative numbers) for the period. List significant individual transactions (> $10).')
append_section "Financial Summary" "$finance_data"

# 6. Explicit Insights (Ideas)
echo "Extracting Insights (💡)..."
insights_data=$(context "$HISTORY_FILE" | hey 'Extract all lines containing the "💡" emoji or explicitly labelled as "Ideas". Include the date and the full line content.')
append_section "Insights & Ideas (💡)" "$insights_data"

# 7. Key Reflections & Commitments
echo "Extracting Key Reflections..."
reflections_data=$(context "$HISTORY_FILE" | hey 'Extract significant personal reflections, analyses of resistance, stated commitments (like quitting alcohol), or descriptions of mood/feeling states (e.g., "feeling great", "lethargic", "anxiety"). Include date for context.')
append_section "Key Reflections & Commitments" "$reflections_data"

# 8. Sprint Goal Progress
echo "Extracting Sprint Progress..."
sprint_data=$(context "$HISTORY_FILE" | hey 'Locate sections starting with "## Sprint". Summarize the overall sprint goal and list the status ([x], [-]) of tasks mentioned under "### Milestones" or "### Today" within those sprint sections for the relevant week.')
append_section "Sprint Goal Progress" "$sprint_data"

# 9. Bookmarks / External Stimuli
echo "Extracting Bookmarks..."
bookmarks_data=$(context "$HISTORY_FILE" | hey 'Extract all URLs listed under "## Bookmarks" sections. Include any brief description provided.')
append_section "Bookmarks & External Stimuli" "$bookmarks_data"


echo "Summary generation complete: $OUTPUT_FILE"

# Optional: Copy to clipboard
# cat "$OUTPUT_FILE" | xsel -ib
# echo "Summary copied to clipboard."
