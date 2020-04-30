function m = nanstd(v)
    m = std(v(~isnan(v)));
end