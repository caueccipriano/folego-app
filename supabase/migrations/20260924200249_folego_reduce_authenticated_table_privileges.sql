revoke truncate, references, trigger on all tables in schema public from authenticated;
alter default privileges for role postgres in schema public
  revoke truncate, references, trigger on tables from authenticated;
