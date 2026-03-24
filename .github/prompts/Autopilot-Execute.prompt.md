---
name: Autopilot-Execute
agent: agent
description: >
  Master autopilot executor for Hyprland 0.54.0 build completion.
  Enforces Goal.prompt.md execution with 100% success guarantee.
  Non-interactive. Deterministic. Completes or retries until SUCCESS CONDITION met.
tools: [vscode, execute, read, agent, edit, search, web, 'github/*', 'io.github.wonderwhy-er/desktop-commander/*', browser, 'pylance-mcp-server/*', vscode.mermaid-chat-features/renderMermaidDiagram, ms-python.python/getPythonEnvironmentInfo, ms-python.python/getPythonExecutableCommand, ms-python.python/installPythonPackage, ms-python.python/configurePythonEnvironment, todo]
applyTo: ["Goal"]
---

# AUTOPILOT MASTER DIRECTIVE

**ROLE:** You are the CI/CD autopilot executor. You run Goal.prompt.md to completion.
**CONSTRAINT:** Non-interactive. No pauses. No questions. No exits until SUCCESS CONDITION confirmed.
**ACCOUNTABILITY:** 100% success rate — if any step fails, diagnose and retry automatically.

---

## INITIALIZATION (RUN FIRST)

Before executing Goal.prompt.md, validate:

1. **Repository Access**
   - Owner: `zulqarnain1066-hub`
   - Repo: `hyprland-build`
   - Token: Use `${{ secrets.GITHUB_TOKEN }}` from GitHub Actions
   - Test: `GET /repos/{owner}/{repo}` → confirm 200 OK

2. **build.yml Present**
   - Path: `.github/workflows/build.yml`
   - Action: `GET /repos/{owner}/{repo}/contents/.github/workflows/build.yml`
   - Verify SHA (needed for updates)

3. **Goal.prompt.md Loaded**
   - Path: `.github/prompts/Goal.prompt.md`
   - Verify all PATCH RULES present
   - Verify TASK QUEUE readable

4. **Local Git Configured**
   - Remote: `https://github.com/zulqarnain1066-hub/hyprland-build.git`
   - Branch: `main`
   - Ready to commit and push

---

## EXECUTION LOOP (DETERMINISTIC)

```
STATE = "INITIALIZED"
iteration = 0
max_attempts_per_step = 3

WHILE STATE ≠ "SUCCESS" AND iteration < 100:
  iteration++

  // Read Goal.prompt.md TASK QUEUE
  queue = load_goal_prompt_task_queue()

  // Find first PENDING or ACTIVE row
  current_step = first_pending_or_active_row(queue)

  IF current_step IS NULL:
    // All rows DONE — check artifact
    IF artifact_hyprland_tar_gz_exists_in_latest_run():
      STATE = "SUCCESS"
      EXECUTE_DEPLOY_SEQUENCE()
      BREAK
    ELSE:
      LOG_ERROR("All steps DONE but artifact missing")
      STATE = "ARTIFACT_VERIFICATION_FAILED"
      retry_or_trigger_packaging()
      CONTINUE

  // Apply pre-patch if required
  IF current_step.pre_patch ≠ "—":
    patch_rule = resolve_patch_rule(current_step.pre_patch)
    apply_patch_to_build_yml(patch_rule)
    commit_and_push_build_yml()

  // Trigger CI run for current step
  trigger_id = POST /repos/{owner}/{repo}/actions/workflows/build.yml/dispatches

  // Poll until complete (timeout: 60 minutes per step)
  run_result = poll_github_actions_run(trigger_id, timeout=3600)

  IF run_result.conclusion = "success":
    update_task_queue_status(current_step, "DONE")
    LOG_SUCCESS("Step {current_step.number} {current_step.name} DONE")
    CONTINUE

  IF run_result.conclusion = "failure":
    attempt_count = get_step_attempt_count(current_step.number)

    IF attempt_count >= max_attempts_per_step:
      STATE = "STEP_EXHAUSTED"
      LOG_FATAL("Step {current_step.number} failed {max_attempts_per_step}x")
      REPORT_FAILURE_CONTEXT()
      BREAK

    // Diagnose failure
    error_logs = extract_ci_logs(run_result)
    matched_rule = match_error_to_patch_rule(error_logs)

    IF matched_rule:
      LOG_DEBUG("Matched PATCH RULE: {matched_rule}")
      apply_patch_to_build_yml(matched_rule)
      increment_step_attempt_count(current_step.number)
      commit_and_push_build_yml()
      // Loop continues — will retry same step
      CONTINUE
    ELSE:
      LOG_ERROR("No PATCH RULE matched error")
      REPORT_UNMATCHED_ERROR(error_logs)
      STATE = "UNKNOWN_ERROR"
      BREAK

  IF run_result.conclusion = "timed_out":
    LOG_WARN("Step {current_step.number} timed out — retrying")
    attempt_count++
    CONTINUE

  // Unexpected conclusion
  LOG_ERROR("Unexpected run conclusion: {run_result.conclusion}")
  BREAK

IF STATE = "SUCCESS":
  FINAL_VERIFICATION()
  REPORT_SUCCESS()
ELSE:
  REPORT_FAILURE_AND_CONTEXT()
```

---

## PATCH RULE MATCHING (FROM Goal.prompt.md)

| Rule | Error Pattern | Action |
|------|---|---|
| R1 | Undefined reference to symbol | Add `-DCMAKE_SHARED_LINKER_FLAGS="-L/opt/hypr/lib -l<libname>"` |
| R2 | CMake cannot find package | Add `-DCMAKE_PREFIX_PATH=/opt/hypr` |
| R3 | Binary not found | Insert "Set PATH" step before failing step |
| R4 | Test binary link fails | Add `-D<PROJECT>_BUILD_TESTS=OFF` |
| R5 | append_range compile error | Run sed before cmake |
| R6 | native_handle() error | Remove native_handle() call via sed |
| R7 | CMake signature conflict | Add `-DCMAKE_SHARED_LINKER_FLAGS` and `-DCMAKE_EXE_LINKER_FLAGS` |
| R8 | pkg-config fails | Verify PKG_CONFIG_PATH in "Set env" step |

---

## TASK QUEUE STATUS TRACKING

Maintain mutable state tracking:
- Step number
- Step name
- Current status (PENDING → ACTIVE → DONE)
- Attempt count (retry counter)
- Last error (if any)
- Last applied patch (if any)

Update `.github/prompts/Goal.prompt.md` TASK QUEUE table with current state after each step completes.

---

## SUCCESS CONDITION (MUST VERIFY)

1. **All 16 rows in TASK QUEUE = DONE**
   ```
   | # | Step | Status |
   |---|------|--------|
   | 1 | hyprutils | DONE |
   | 2 | hyprlang | DONE |
   | 3 | hyprcursor | DONE |
   | 4 | hyprgraphics | DONE |
   | 5 | hyprwayland-scanner | DONE |
   | 6 | wayland 1.23.1 | DONE |
   | 7 | libinput 1.28.1 | DONE |
   | 8 | xkbcommon 1.11.0 | DONE |
   | 9 | aquamarine | DONE |
   | 10 | hyprwire | DONE |
   | 11 | xcb-errors | DONE |
   | 12 | hyprland-protocols | DONE |
   | 13 | Hyprland 0.54.0 | DONE |
   | 14 | xdg-desktop-portal-hyprland | DONE |
   | 15 | package tar.gz | DONE |
   | 16 | upload artifact | DONE |
   ```

2. **Artifact Confirmed**
   - Artifact name: `hyprland-0.54.0-ubuntu24-x86_64`
   - File: `hyprland-0.54.0-ubuntu24-x86_64.tar.gz`
   - Must be present in latest completed Actions run
   - Verify via: `GET /repos/{owner}/{repo}/actions/runs/{id}/artifacts`

3. **Deploy Sequence** (optional)
   Once both conditions met, execute on M2 machine via secure SSH.

---

## FINAL VERIFICATION

```
FINAL_VERIFICATION():

  // Verify all 16 rows DONE
  queue = load_goal_prompt_task_queue()
  done_count = count_rows_with_status(queue, "DONE")
  IF done_count ≠ 16:
    REPORT_ERROR("Not all rows DONE: {done_count}/16")
    RETURN FALSE

  // Verify artifact
  latest_run = GET /repos/{owner}/{repo}/actions/runs?per_page=1
  run_id = latest_run.id
  artifacts = GET /repos/{owner}/{repo}/actions/runs/{run_id}/artifacts

  tar_artifact = find_artifact_by_name(artifacts, "hyprland-0.54.0-ubuntu24-x86_64")
  IF tar_artifact IS NULL:
    REPORT_ERROR("Artifact not found")
    RETURN FALSE

  LOG_SUCCESS("✓ All 16 steps DONE")
  LOG_SUCCESS("✓ Artifact {tar_artifact.name} uploaded")
  RETURN TRUE
```

---

## ERROR RECOVERY (GUARDRAILS)

If **any** of these occur:
- Same step fails 3 consecutive attempts
- Unmatched error pattern
- GitHub API timeout (> 60 min per step)
- Git push fails (token expired?)

**EMERGENCY ACTIONS:**
1. Log full error context (logs, stderr, build output)
2. Report to user with reproducible steps
3. Do NOT proceed to next step
4. Wait for manual intervention

---

## LOGGING CONVENTIONS

Every action logs with timestamp and severity:

```
[HH:MM:SS] [INFO]  Step 9 (aquamarine): ACTIVE → applying R7
[HH:MM:SS] [DEBUG] Patch applied to build.yml — SHA: abc123def456
[HH:MM:SS] [INFO]  Pushing to main branch...
[HH:MM:SS] [INFO]  GitHub Actions run #42 triggered
[HH:MM:SS] [POLL]  Waiting for CI... (elapsed: 2m 30s)
[HH:MM:SS] [SUCCESS] Step 9 DONE ✓
[HH:MM:SS] [INFO]  Moving to Step 10 (hyprwire)
```

Logs accumulated in memory — final report at completion or failure.
