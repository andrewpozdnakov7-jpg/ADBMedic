# Diagnostic patterns (synthetic educational content)

This file is not a log of any real person's device. It contains general diagnostic cautions.

- A sustained high CPU sample identifies an observed process load, not a root cause.
- A locked wait in one native stack snapshot does not prove a deadlock.
- An empty active-camera-client list describes only that particular moment.
- A restart that temporarily restores normal load is a mitigation, not proof of the original trigger.
- Historical counters and instantaneous measurements must never be conflated.
- Correlate all measurements with sampling time and screen/charge state.

Synthetic example (all identifiers are artificial):

    Process: com.example.synthetic_hardware_service
    PID: 1000 (TEST ONLY)
    CPU: 0% (TEST ONLY)

Do not add real device model names, serial numbers, original stack traces or private investigation results.
