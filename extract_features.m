function f = extract_features(e, sys, paths, downstream)
    ds = downstream{e};
    if isempty(ds)
        f = zeros(1,7); return;
    end
    Psum  = sum(sys.Pload_kW(ds)) / 1000;
    nDown = numel(ds);
    crit  = sum(sys.Pload_kW(ds) > 150) / max(nDown,1);
    dist  = numel(paths{sys.to(e)});
    Zmag  = sqrt(sys.R(e)^2 + sys.X(e)^2);
    avgP  = Psum / max(nDown,1);
    wPsum = sum(sys.wImp(ds) .* sys.Pload_kW(ds)) / 1000;
    f = [Psum, nDown, crit, dist, Zmag, avgP, wPsum];
end