function m = nanmean(v)
    m = mean(v(~isnan(v)));
end