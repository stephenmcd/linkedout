# encoding: UTF-8
# (for unicode bullets regex that works consistently across Ruby 1.8 and 1.9)

helpers do
  # Splits the given data into sections where each section is either
  # a string paragraph, or a list of bullet points. The near_items
  # arg is the other items in the same list that the data arg is from
  # and are used to treat the data like bullet points if most of the
  # other items are bullet points.
  def sections(data, near_items)
    bullets = /^(\*|-|–|—|·|•)/
    most_near_are_points = most_near_are_points? near_items
    (data || "").split("\n\n").map {|section|
      points = section.split("\n").map{ |point| point.strip }
      # The section is bullet points if all the lines start with a bullet.
      is_points = points.reject {|point| point =~ bullets}.size == 0
      if is_points || most_near_are_points
        # Bullet points - remove the bullet from each point.
        points.map {|point| point.gsub(bullets, "").strip}
      else
        # Just a paragraph of text.
        section.gsub("\n", "<br>")
      end
    }
  end

  # Used in the sections helper to determine if most of the other
  # items in the same list that the sections is in, are bullet
  # points. If so then the section can be treated as bullet points
  # even if it doesn't look like one.
  def most_near_are_points?(near_items)
    # Convert all the items to a flat list of sections.
    near_sections = near_items.map {|n| sections n, []}.flatten 1
    # Return true if more than half the sections are bullet points.
    near_sections.select {|n| n.is_a? Array}.size > near_sections.size / 2
  end

  # Takes an item with start_date and end_date properties and returns
  # a date string with month name.
  def dates(item)
    [item.start_date, item.end_date].each_with_index.map {|date, i|
        month = date && date.month ? Date::MONTHNAMES[date.month] : ""
        year = date && date.year ? date.year : ""
        item.is_current && i == 1 ? "Present" : "#{month} #{year}".strip
    }.reject {|date| date.size == 0}.join(" - ")
  end

  # Shortcut for checking string has a value.
  def exists?(data)
    data && !data.strip.empty?
  end
end
