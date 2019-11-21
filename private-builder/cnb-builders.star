load("@ytt:struct", "struct")
load("@ytt:data", "data")
load("cnb-builders.lib.yml", "source")
stacks = struct.decode(data.values.stacks)
all_cnbs = struct.decode(data.values.cnbs)

cnbs = {k:v for (k, v) in all_cnbs.items() if v.get("public")}
p_cnbs = {k:v for (k, v) in all_cnbs.items() if v.get("private")}

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

def _cnbs(self):
  cnb = p_cnbs if self.private else cnbs
  val = [k for (k,v) in cnb.items() if self.stack in v.get("skip_stack")]
  return val
end

def _tags(self):
  tags = self.stack + " " + stacks.get(self.stack)
  if self.latest:
    tags += " latest"
  end
  return tags
end


#!  def cnb_hash(builder_data)
#!    all_cnb_hash = builder_data["private"] ? piv_cnbs : cnbs
#!    cnb_hash = all_cnb_hash.reject{|cnb, data| data.fetch("skip_stack",[]).include? builder_data.fetch("stack")}
#!    cnb_hash.keys
#!  end
