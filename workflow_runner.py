#!/usr/bin/env python3
"""
Local GitHub Actions Workflow Runner

This script parses a GitHub Actions workflow YAML file and executes the 'run' steps locally.
It includes auto error handling with retries on failures.

Usage: python workflow_runner.py <workflow.yml>
"""

import logging
import subprocess
import sys
import time

import yaml

# Set up logging
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)


def run_command(command, retries=3):
    """Run a shell command with retries on failure."""
    for attempt in range(retries + 1):
        try:
            logging.info(f"Running command (attempt {attempt + 1}): {command}")
            result = subprocess.run(
                command, shell=True, check=True, capture_output=True, text=True
            )
            logging.info(f"Command succeeded: {command}")
            return result
        except subprocess.CalledProcessError as e:
            logging.error(f"Command failed (attempt {attempt + 1}): {command}")
            logging.error(f"Error output: {e.stderr}")
            if attempt < retries:
                logging.info("Retrying in 5 seconds...")
                time.sleep(5)
            else:
                logging.error(f"Command failed after {retries + 1} attempts: {command}")
                raise e


def parse_and_run_workflow(workflow_file):
    """Parse the workflow YAML and run the jobs."""
    with open(workflow_file, "r") as f:
        workflow = yaml.safe_load(f)

    if "jobs" not in workflow:
        logging.error("No jobs found in workflow.")
        return

    for job_name, job in workflow["jobs"].items():
        logging.info(f"Running job: {job_name}")
        if "steps" in job:
            for step in job["steps"]:
                if "run" in step:
                    run_command(step["run"])
                else:
                    logging.info(
                        f"Skipping non-run step: {step.get('name', 'unnamed')}"
                    )
        else:
            logging.warning(f"No steps in job: {job_name}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python workflow_runner.py <workflow.yml>")
        sys.exit(1)

    workflow_file = sys.argv[1]
    try:
        parse_and_run_workflow(workflow_file)
        logging.info("Workflow completed successfully.")
    except Exception as e:
        logging.error(f"Workflow failed: {e}")
        sys.exit(1)
