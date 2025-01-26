#!/bin/bash -xe

function set_yaml_value_from_file_contents {
  local VAULT_FILE="$1"
  local VARIABLE_NAME="$2"
  local VARIABLE_CONTENT_FILE_PATH="$3"

  local QUERY=".$VARIABLE_NAME = load_str(\"$VARIABLE_CONTENT_FILE_PATH\")"

  # NOTE: There is a bug in yq, it strips whitespace when updating the yaml file, this screws up the diff, but we don't care as much for the encrypted ansible vault file https://github.com/mikefarah/yq/issues/515
  # This query works, but trims all/most whitespace up to yq 4.4.1 at least
  #yq -i "$QUERY" "$VAULT_FILE"

  # So we do this complicated dance where we do the change, then do a diff with whitespace subtracted to work out what the actual change was, then apply just that change https://github.com/mikefarah/yq/issues/515#issuecomment-2242301795
  # Step 1: Update the value and create a copy
  yq "$QUERY" "$VAULT_FILE" > "$VAULT_FILE.new"

  # Step 2: Remove blanks from the original
  yq '.' "$VAULT_FILE" > "$VAULT_FILE.noblanks"

  # Step 3: Create a patch of just the line that has changed, no whitespace changes
  diff -B "$VAULT_FILE.noblanks" "$VAULT_FILE.new" > "$VAULT_FILE.patch"

  # Step 4: Apply the patch to the original
  patch "$VAULT_FILE" "$VAULT_FILE.patch"
}
