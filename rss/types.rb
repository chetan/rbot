#-- vim:sw=2:et
#++

rss_type(:twitter) do |s|
    line1 = "%{date}%{title}"
    make_stream(line1, nil, s)
end

rss_type(:tinydefault) do |s|
    s[:link] = WWW::ShortURL.shorten(s[:link], :tinyurl)
    line1 = "%{handle}%{date}%{title}%{at}%{link}"
    line1 << " (by %{author})" if s[:author]
    make_stream(line1, nil, s)
end
