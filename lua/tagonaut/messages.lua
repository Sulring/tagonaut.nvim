return {
  invalid_tag_info = "Error: Invalid tag information",

  tag_added = function(tag_name)
    return string.format("Tag '%s' added", tag_name)
  end,

  tag_deleted = function(tag_name)
    return string.format("Tag '%s' deleted", tag_name)
  end,

  tags_cleared = function()
    return "All tags cleared."
  end,

  shortcut_set = function(shortcut, tag_name)
    return string.format("Assigned shortcut '%s' to tag '%s'", shortcut, tag_name)
  end,

  shortcut_removed = function(shortcut, tag_name)
    return string.format("Removed shortcut '%s' from tag '%s'", shortcut, tag_name)
  end,

  no_tag_for_shortcut = function(shortcut)
    return string.format("No tag found for shortcut '%s'", shortcut)
  end,

  operation_cancelled = "Operation cancelled.",

  confirm_clear_tags = "Are you sure you want to clear all tags? (y/n): ",

  assign_shortcut_prompt = "Enter shortcut: ",

  rename_tag_prompt = "Enter new tag name: ",

  jumped_to_tag = function(tag_name)
    return string.format("Jumped to tag '%s'", tag_name)
  end,

  tag_not_found = function(identifier)
    if type(identifier) == "number" then
      return string.format("Tag with ID %d not found", identifier)
    else
      return string.format("Tag '%s' not found", identifier)
    end
  end,

  jumped_to_symbol = function(symbol_name)
    return string.format("Jumped to symbol '%s'", symbol_name)
  end,

  failed_to_jump_to_symbol = function(symbol_name)
    return string.format("Failed to jump to symbol '%s'", symbol_name)
  end,

  tag_restored = function(tag_name)
    return string.format("Tag '%s' has been restored", tag_name)
  end,

  tag_renamed = function(old_name, new_name)
    return string.format("Tag '%s' renamed to '%s'", old_name, new_name)
  end,

  no_more_tags = "No more tags to navigate to.",

  not_on_tag = "Current cursor position is not on a tag.",

  no_tags_available = "No tags available in current workspace.",

  workspace_not_found = "Current workspace not found.",

  jump_failed = function(tag_name, reason)
    return string.format("Failed to jump to tag '%s': %s", tag_name, reason)
  end,

  switched_to_buffer = function(tag_name)
    return string.format("Switched to buffer containing tag '%s'", tag_name)
  end,

  workspace_created = function(name)
    return string.format("Created new workspace '%s'", name)
  end,

  workspace_switched = function(path)
    return string.format("Switched to workspace: %s", path)
  end,

  workspace_invalid = function(path)
    return string.format("Invalid workspace path: %s", path)
  end,

  shortcut_already_exists = function(shortcut)
    return string.format("Shortcut '%s' is already assigned to another tag", shortcut)
  end,

  shortcut_invalid = function(shortcut)
    return string.format("Invalid shortcut '%s'", shortcut)
  end,

  tag_exists = function(tag_name)
    return string.format("Tag '%s' already exists", tag_name)
  end,

  invalid_workspace = function(path)
    return string.format("Invalid workspace path: %s", path)
  end,

  symbol_not_found = "No symbol found at cursor position",

  symbol_renamed = function(old_name, new_name)
    return string.format("Symbol '%s' renamed to '%s'", old_name, new_name)
  end,

  symbol_references_updated = function(count)
    return string.format("Updated %d symbol references", count)
  end,

  preview_not_available = "Preview not available for this tag",

  searching_workspace = "Searching workspace tags...",

  no_matching_tags = "No matching tags found",

  multiple_matches = function(count)
    return string.format("Found %d matching tags", count)
  end,
}
