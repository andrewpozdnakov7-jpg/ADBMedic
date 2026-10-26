# Android diagnostic playbook

## CPU
- Start with fresh top samples and the first, current section of dumpsys cpuinfo.
- For sustained load, find process PID and thread TID with top -H.
- A value near 100% commonly represents one occupied logical core.
- TIME+ means accumulated CPU time, not wall-clock uptime.
- A sleeping thread shown as S and 0% in fresh top intervals is not itself a current CPU drain.

## Battery and sleep
- Compare on-battery screen-off elapsed time, awake/sleep time, charge state, and estimated discharge.
- BatteryStats mAh are modeled estimates, not direct measurements.
- Wakelocks, alarms and jobs require correlation with discharge windows.

## Camera HAL
- A vendor camera-provider system service is not, by itself, evidence of recording.
- Align CPU samples and active CameraService client snapshots in time.
- If HAL uses one core without an active camera session, document PID, TID, stack and kernel/user split.
- A face-unlock service may exist even when face unlock is off. Brief camera client events do not establish causation.
- Never kill the camera service in an automatic diagnostic test.

## Sensors
- Vendor camera libraries may use sensor interfaces outside ordinary SensorService client listings.
- Many sensor events do not automatically establish substantial battery drain.

## Evidence
- Separate observed symptom, likely failure mechanism, triggering event and mitigation.
- Do not overstate causality or recommend destructive operations.
