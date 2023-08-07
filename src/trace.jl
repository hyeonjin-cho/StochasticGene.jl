### trace.jl

"""
    simulate_trace_vector(r, par, transitions, G, R, onstates, interval, steps, ntrials)

TBW
"""
function simulate_trace_vector(r, par, transitions, G, R, onstates, interval, steps, ntrials)
    trace = Array{Array{Float64}}(undef, ntrials)
    for i in eachindex(trace)
        trace[i] = simulator(r, transitions, G, R, 0, 1, 1, onstates=onstates, traceinterval=interval, totalsteps=steps, par=par)[1:end-1, 2]
    end
    trace
end

"""
    simulate_trace(r,transitions,G,R,interval,totaltime,onstates=[G])

TBW
"""
simulate_trace(r,transitions,G,R,interval,totaltime,onstates=[G]) = simulator(r, transitions, G, R, 0, 1, 1, onstates=onstates, traceinterval=interval, totaltime=totaltime, par=r[end-3:end])[1:end-1, :]

"""
    trace_data(trace, interval)

TBW
"""
function trace_data(trace, interval)
    TraceData("trace", "test", interval, trace)
end

"""
    trace_model(r::Vector, transitions::Tuple, G, R; onstates=[G], propcv=0.05, f=Normal, cv=1.0)

TBW
"""
function trace_model(r::Vector, transitions::Tuple, G, R; onstates=[G], propcv=0.05, f=Normal, cv=1.0, npars = 4)
    ntransitions = length(transitions)
	fittedparam = [1:ntransitions+R+1; ntransitions+R+3:ntransitions+R+2+npars]
	trace_model(r, transitions, G, R, fittedparam, onstates=onstates, propcv=propcv, f=f,cv=cv)
 end

"""
    trace_model(r::Vector, transitions::Tuple, G, R, fittedparam; onstates=[G], propcv=0.05, f=Normal, cv=1.)

TBW
"""
function trace_model(r::Vector, transitions::Tuple, G, R, fittedparam; onstates=[G], propcv=0.05, f=Normal, cv=1.)
	d = trace_prior(r, fittedparam,f,cv)
	method = 1
	if R == 0
		components = make_components_T(transitions, G)
		return GMmodel{typeof(r),typeof(d),typeof(propcv),typeof(fittedparam),typeof(method),typeof(components)}(G, 1, r, d, propcv, fittedparam, method, transitions, components, onstates)
	else
		components = make_components_T(transitions, G, R)
		return GRMmodel{typeof(r),typeof(d),typeof(propcv),typeof(fittedparam),typeof(method),typeof(components)}(G,R,1,"",r,d,propcv,fittedparam,method,transitions,components)
	end
end

"""
    trace_options(samplesteps::Int=100000, warmupsteps=0, annealsteps=0, maxtime=1000.0, temp=1.0, tempanneal=100.0)

TBW
"""
function trace_options(samplesteps::Int=100000, warmupsteps=0, annealsteps=0, maxtime=1000.0, temp=1.0, tempanneal=100.0)

    MHOptions(samplesteps, warmupsteps, annealsteps, maxtime, temp, tempanneal)

end

"""
    trace_prior(r,fittedparam,f=Normal)

TBW
"""
function trace_prior(r,fittedparam,f=Normal,cv = 1.)
	rcv = cv * ones(length(r))
	distribution_array(log.(r[fittedparam]),sigmalognormal(rcv[fittedparam]),f)
end

"""
    read_tracefiles(path::String,cond::String,col=3)

TBW
"""
function read_tracefiles(path::String,cond::String,col=3)
    traces = Vector[]
    for (root,dirs,files) in walkdir(path)
        for file in files
            target = joinpath(root, file)
            if occursin(cond,target)
                # println(target)
                push!(traces, read_tracefile(target,col))
            end
        end
    end
    return traces
end

"""
    read_tracefile(target::String,col=3)

TBW
"""
read_tracefile(target::String,col=3) = readdlm(target)[:,col]