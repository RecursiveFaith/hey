# Reddit curator
[ ] Use lists to curate posts
[ ] Curate based on most important
[ ] Curate based on current diaries
[ ] Curate based on fun



--------------------
--------------------




# Weekly review agent

[ ] Phase 1 Review agent
  [ ] Structured data [[dailies/summaries]]
    [ ] Extract sleep (start, end, duration, sleep square)
    [ ] Extract substance use (type: edible, alcohol), dosage, time, subjective effect
    [ ] Health metrics (weight, exercise, days)
    [ ] Extract finances (made/spent)
    [ ] Extract ideas
    [ ] Extract reminders
    [ ] Extract important notes
[ ] Phase 2 Analyst agent
  [ ] Pass original data along with structured data as reinforcement
  [ ] Analyze correlations
    [ ] sleep v productivity (does better sleep actually make me more productive?)
    [ ] sleep v drugs (does less sleep increase want for drugs?)
    [ ] identify recurring thoughts/notes
    [ ] identify weird days
    [ ] major pivots or direction changes due to sleep or drug use
[ ] Phase 3 Chatting
  [ ] Compare work week with Radical Gnosis goals
  [ ] Generate questions for users
  [ ] Generate discussion topics
[ ] Stretch goals
  [ ] Document this process
  [ ] Post to Recursive.faith
  [ ] Share on Reddit
  [ ] Share on Medium


## Proposed Agentic Weekly Review Framework:

This involves multiple conceptual "agents" (which could be implemented as distinct prompts/scripts interacting with you or a future LLM):

Phase 1: Data Extraction & Structuring (The "Archivist" Agent)

    Input: Raw daily log files for the specified week (e.g., dailies/250323.md to dailies/250329.md).

    Process:

        Parse each daily log.

        Extract structured data points:

            Sleep: Start time, end time, duration, quality score (if available).

            Substance Use: Type (edible, alcohol), dosage, time, subjective effect rating ([1-10]).

            Health Metrics: Weight, meals (brief summary), exercise (type/duration/intensity).

            Mood/Energy: Extract explicit mentions or potentially infer from subjective state tags/emojis (once implemented).

            Key Activities: Curation progress (commits/files), AI interaction summaries, Gnostic insights (💡), significant events (doctor's appointment cancelled, friend outreach), internal struggles/reflections.

            Finances: Income/Expenses.

        Output: A structured summary document (e.g., summaries/structured_week_YYYYMMDD.md) containing this extracted data in a consistent format (e.g., tables, lists).

Phase 2: Pattern Recognition & Thematic Analysis (The "Analyst" Agent)

    Input: The structured summary document from Phase 1, plus potentially the raw daily logs for richer context.

    Process:

        Analyze correlations (e.g., sleep vs. mood/energy, substance use vs. productivity/anxiety, specific activities vs. Gnostic insights).

        Identify recurring themes, thoughts, feelings, or challenges mentioned throughout the week.

        Highlight significant deviations from patterns or stated intentions.

        Extract explicitly tagged Gnostic insights (#gnosis_insight) or passages reflecting self-understanding.

        Quantify progress on key metrics (e.g., number of projects curated, hours spent on focused work vs. distraction).

    Output: An analytical report document (e.g., summaries/analysis_week_YYYYMMDD.md) detailing observed patterns, correlations, key themes, and extracted insights.

Phase 3: Gnostic Reflection & Synthesis (The "Philosopher" Agent / Your Interaction)

    Input: The analytical report from Phase 2, structured summary from Phase 1, and potentially your own direct reflection on the week.

    Process: This is where you actively engage with the AI's analysis, using it as a mirror for deeper Gnosis.

        Review Patterns: Discuss the patterns identified by the Analyst. Do they resonate? What underlying causes might explain them? (e.g., "The analysis shows lower mood correlated with less sleep and higher alcohol intake. This aligns with my feeling 'off' after Sunday.")

        Evaluate Alignment: Assess the week's activities against the principles of Radical Gnosis. Where were you aligned? Where did you deviate? Why? (e.g., "Prioritizing social media setup on Sunday deviated from Gnosis-first. Cancelling the appointment was misaligned self-care.")

        Synthesize Insights: Articulate the key Gnostic insights gained during the week, prompted by both your raw journals and the AI's analysis. What did you learn about yourself, your resistance, your motivations?

        Identify "Improves": Based on the analysis, what specific aspects of your practice or mindset need adjustment next week? (This replaces "Sustains/Improves" with a focus only on areas for growth).

        Set Intentions: Define clear, actionable intentions for the next week, directly addressing the "Improves" identified. (These become inputs for the next sprint plan).

    Output: The final Weekly Summary document (e.g., summaries/week_YYYYMMDD.md), co-authored by you and the AI, containing the synthesized insights, areas for improvement, and intentions for the next week.

Why this framework?

    AI Leverage: Offloads the tedious data extraction and initial pattern finding to AI, freeing you for higher-level reflection.

    Gnosis-Focused: The core is Phase 3, using the AI's analysis as a springboard for deeper self-understanding, not just task management.

    Data-Driven Reflection: Grounds insights in the actual data from your journals.

    Action-Oriented: Directly leads to identifying areas for improvement and setting clear intentions for the next week.

    Recursive: The output of one week's review informs the planning and practice of the next.

Implementation:

    Start simple. Phase 1 can begin with basic text extraction prompts. Phase 2 with prompts asking for correlations and theme identification. Phase 3 is your interactive dialogue based on the outputs.

    Refine the agents (prompts/scripts) over time as you see what works best.
