module ApplicationHelper
  def nav_link_class(path)
    classes = ["transition", "no-underline"]
    if current_page?(path)
      classes.concat(["text-white", "font-medium"])
    else
      classes.concat(["text-slate-400", "hover:text-slate-200"])
    end
    classes.join(" ")
  end
end
