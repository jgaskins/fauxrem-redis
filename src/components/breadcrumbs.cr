require "armature/component"

struct Breadcrumbs(T) < Armature::Component
  def_to_s "components/breadcrumbs"

  def initialize(@path : T)
  end
end
