function timeline = baad_controller_reference(edge_bins, active_found, error)
% Frame-domain interpretation of the current controller; stale-clock watchdog
% is tested by RTL, not inferred from a frame-only model.
n=numel(edge_bins); assert(numel(active_found)==n && numel(error)==n);
m=1; pending=1; stable=0; factors=[16 8 4 2 1]; timeline=zeros(n,5);
for k=1:n
    edge=edge_bins(k);
    nominal=factors(find(edge*2*factors*5<=2048*4,1));
    aggressive=factors(find((edge+10)*2*factors*5<=2048*4,1));
    if isempty(nominal), nominal=1; end
    if isempty(aggressive), aggressive=1; end
    forced=error(k) || ~active_found(k);
    if forced, selected=1;
    elseif edge*2*m*5>2048*4, selected=nominal;
    elseif aggressive>m, selected=aggressive;
    else, selected=m;
    end
    old=m;
    if forced || selected<m
        pending=selected; stable=2; m=selected;
    elseif selected==pending
        stable=min(stable+1,2);
        if selected~=m && stable>=2, m=selected; end
    else
        pending=selected; stable=1;
    end
    timeline(k,:)=[edge selected m stable m~=old];
end
end
