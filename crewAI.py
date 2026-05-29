import os

from crewai import Agent, Crew, Task
from dotenv import load_dotenv


load_dotenv()


PROJECT_CONTEXT = """
Project: fitnesscoach iOS app
Stack: SwiftUI, HealthKit, CrewAI
Current features:
- Dashboard for daily active calories
- Daily calorie goal
- Apple Health / HealthKit integration
- Workout recommendations

Goal:
Improve this app into a polished fitness coach experience with good UI,
reliable behavior, and practical full-stack planning.
"""


ui_agent = Agent(
    role="UI Designer",
    goal="Design a clean, useful, mobile-first SwiftUI fitness dashboard.",
    backstory=(
        "You specialize in iOS product design. You care about clarity, visual "
        "hierarchy, accessibility, and making health data easy to understand."
    ),
    verbose=True,
)

qa_agent = Agent(
    role="QA Tester",
    goal="Find bugs, edge cases, missing states, and test scenarios for the app.",
    backstory=(
        "You test iOS apps carefully. You think about permissions, empty states, "
        "HealthKit availability, failed network calls, and confusing user flows."
    ),
    verbose=True,
)

full_stack_agent = Agent(
    role="Full Stack Engineer",
    goal="Plan practical implementation steps across SwiftUI, backend, and AI agents.",
    backstory=(
        "You are a pragmatic full-stack engineer. You turn product ideas into "
        "small, safe implementation steps and avoid putting secrets in client apps."
    ),
    verbose=True,
)


ui_task = Task(
    description=(
        f"{PROJECT_CONTEXT}\n\n"
        "Review the app concept and propose a better SwiftUI user experience. "
        "Focus on dashboard layout, workout recommendation cards, HealthKit "
        "permission states, daily goal editing, and accessibility."
    ),
    expected_output=(
        "A concise UI plan with sections, screen states, component suggestions, "
        "and accessibility improvements."
    ),
    agent=ui_agent,
)

qa_task = Task(
    description=(
        f"{PROJECT_CONTEXT}\n\n"
        "Create a QA checklist for the app. Cover HealthKit permission flows, "
        "daily calorie calculations, empty data, denied permissions, simulator "
        "behavior, and recommendation logic."
    ),
    expected_output=(
        "A prioritized QA checklist with specific manual test cases and expected results."
    ),
    agent=qa_agent,
)

full_stack_task = Task(
    description=(
        f"{PROJECT_CONTEXT}\n\n"
        "Use the UI and QA perspectives to create an implementation roadmap. "
        "Include what should stay in SwiftUI, what should move to a backend, "
        "how to call AI safely, and the next 5 coding tasks."
    ),
    expected_output=(
        "A practical full-stack implementation roadmap with architecture notes, "
        "security notes, and 5 next coding tasks."
    ),
    agent=full_stack_agent,
    context=[ui_task, qa_task],
)


crew = Crew(
    agents=[ui_agent, qa_agent, full_stack_agent],
    tasks=[ui_task, qa_task, full_stack_task],
    verbose=True,
)


def main() -> None:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError(
            "OPENAI_API_KEY belum terbaca. Set lewat terminal atau simpan di file .env."
        )
    
    # Menghapus newline (\n) atau spasi berlebih dari API key
    os.environ["OPENAI_API_KEY"] = api_key.strip()

    result = crew.kickoff()
    print("\n=== FINAL RESULT ===\n")
    print(result)


if __name__ == "__main__":
    main()
