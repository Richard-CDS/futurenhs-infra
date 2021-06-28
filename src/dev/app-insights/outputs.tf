output forum_instrumentation_key {
  value     = module.forum.forum_instrumentation_key
  sensitive = true
}

output forum_connection_string {
  value     = module.forum.forum_connection_string
  sensitive = true
}