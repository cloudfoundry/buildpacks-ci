load("@ytt:struct", "struct")
load("@ytt:data", "data")
load("cnb-builders.lib.yml", "source")
stacks = struct.decode(data.values.stacks)
all_cnbs = struct.decode(data.values.cnbs)

cnbs = [c for c in all_cnbs if c.get('public', False)]
p_cnbs = [c for c in all_cnbs if c.get('private', False)]

def make_builder(builder):
  return struct.make_and_bind(builder,
    cnbs=_cnbs,
    stack=builder.stack,
    source = source,
    private = builder.private,
    version_key = builder.version_key,
    name = builder.name,
    image_params = builder.builder_image_params,
    tags = _tags,
    latest = builder.latest
  )
end

def _cnbs(builder):
  cnb = p_cnbs if builder.private else cnbs
  val = ["{}-cnb".format(c['name']) for c in cnb if builder.stack not in c.get('skip_stack', [])]
  return val
end

def _tags(self):
  new_name = [stacks.get(self.stack)]
  tags = [self.stack]
  tags += new_name if new_name[0] != self.stack else []
  tags += ["latest"] if self.latest else []
  
  return " ".join(tags)
end