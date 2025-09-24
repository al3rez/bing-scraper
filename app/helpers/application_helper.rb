module ApplicationHelper
  include Pagy::Frontend

  def nav_link_class(path)
    classes = ["text-sm", "font-medium", "transition", "no-underline", "hover:text-slate-900"]
    if current_page?(path)
      classes.concat(["text-slate-900", "underline", "decoration-2", "underline-offset-8", "decoration-blue-500"])
    else
      classes.concat(["text-slate-500"])
    end
    classes.join(" ")
  end
end
