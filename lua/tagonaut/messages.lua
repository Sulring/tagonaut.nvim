return {
  invalid_tag_info = "Error: Invalid tag information",
  tag_added = function(tag_name, is_global)
    return string.format("Tag '%s' added %s", tag_name, is_global and "globally" or "locally")
  end,
  tag_deleted = function(tag)
    return string.format("Tag '%s' deleted", tag)
  end,
  tags_cleared = function(include_global)
    return include_global and "All tags cleared (including global)." or "All local tags cleared."
  end,
  key_assigned = function(key, tag)
    return string.format("Assigned key [%s] to tag '%s'", key, tag)
  end,
  key_removed = function(key, tag)
    return string.format("Removed key [%s] from tag '%s'", key, tag)
  end,
  key_not_found = function(key)
    return string.format("No tag found for key [%s]", key)
  end,
  all_keys_cleared = "All assigned keys have been cleared.",
  operation_cancelled = "Operation cancelled.",
  confirm_clear_all_tags = "Are you sure you want to clear all tags (including global)? (y/n): ",
  confirm_clear_local_tags = "Are you sure you want to clear all local tags? (y/n): ",
  confirm_clear_all_keys = "Are you sure you want to clear all assigned keys? (y/n): ",
  assign_key_prompt = "Assign key: ",
  jumped_to_tag = function(tag)
    return string.format("Jumped to tag '%s'", tag)
  end,
  tag_not_found = function(tag)
    return string.format("Tag '%s' not found", tag)
  end,
  no_tag_for_key = function(key)
    return string.format("No tag assigned to key '%s'", key)
  end,
  tag_restored = function(tag)
    return string.format("Tag '%s' has been restored", tag)
  end,
  tag_renamed = function(old_tag, new_tag)
    return string.format("Tag '%s' renamed to '%s'", old_tag, new_tag)
  end,
  no_more_tags = "No more tags to navigate to.",
  not_on_tag = "Current cursor position is not on a tag.",
  goto_next_tag = "Go to the next tag.",
  goto_prev_tag = "Go to the prev tag.",
  jumped_to_symbol = function(symbol_name)
    return string.format("Jumped to symbol '%s'", symbol_name)
  end,
  failed_to_jump_to_symbol = function(symbol_name)
    return string.format("Failed to jump to symbol '%s'", symbol_name)
  end,
  switched_to_buffer = function(tag)
    return string.format("Switched to buffer containing tag '%s'", tag)
  end,
}
