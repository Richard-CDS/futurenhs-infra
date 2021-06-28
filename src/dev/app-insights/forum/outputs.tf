output forum_instrumentation_key {
  value     = module.forum_production_slot.forum_instrumentation_key
  sensitive = true
}

output forum_connection_string {
  value     = module.forum_production_slot.forum_connection_string
  sensitive = true
}