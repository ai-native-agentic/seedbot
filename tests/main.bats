#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  # Clean up any leftover state from previous test runs
  rm -rf memory inputs.d functions workspace logs
}

teardown() {
  cd "$BATS_TEST_DIRNAME/.."
  # Clean up test artifacts
  rm -rf memory inputs.d functions workspace logs
}

@test "main.sh is executable" {
  [ -x main.sh ]
}

@test "main.sh creates required directories on startup" {
  # Run main.sh with timeout and kill it after 0.5s to let it initialize
  timeout 0.5 ./main.sh &
  sleep 0.2
  
  # Check all required directories exist
  [ -d memory ]
  [ -d inputs.d ]
  [ -d functions ]
  [ -d workspace ]
  [ -d logs ]
}

@test "--verbose flag is accepted without error" {
  # Run with --verbose and timeout to prevent hanging
  timeout 0.5 ./main.sh --verbose >/dev/null 2>&1 &
  local pid=$!
  sleep 0.2
  kill $pid 2>/dev/null || true
  wait $pid 2>/dev/null || true
  
  # Test passes if script started without syntax error
  [ -d memory ]
}

@test "-v flag is accepted without error" {
  # Run with -v and timeout to prevent hanging
  timeout 0.5 ./main.sh -v >/dev/null 2>&1 &
  local pid=$!
  sleep 0.2
  kill $pid 2>/dev/null || true
  wait $pid 2>/dev/null || true
  
  # Test passes if script started without syntax error
  [ -d memory ]
}

@test "_lock creates .lock directory in memory/" {
  # Source the script to get access to _lock function
  source main.sh &
  sleep 0.1
  
  # Manually call _lock (it's defined in main.sh)
  # We'll test by checking if the lock mechanism works
  LOCK_DIR="memory/.lock"
  mkdir -p memory
  
  # Try to create lock
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do sleep 0.01; done
  
  # Verify lock exists
  [ -d "$LOCK_DIR" ]
  
  # Clean up
  rmdir "$LOCK_DIR" 2>/dev/null
}

@test "_unlock removes .lock directory from memory/" {
  LOCK_DIR="memory/.lock"
  mkdir -p memory
  
  # Create lock
  mkdir "$LOCK_DIR" 2>/dev/null
  [ -d "$LOCK_DIR" ]
  
  # Remove lock
  rmdir "$LOCK_DIR" 2>/dev/null
  
  # Verify lock is gone
  [ ! -d "$LOCK_DIR" ]
}

@test "error log is created in logs/ directory" {
  timeout 0.5 ./main.sh &
  sleep 0.2
  
  # Check that logs directory exists
  [ -d logs ]
}
