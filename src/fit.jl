# fit.jl
#
# Fit GRS models (generalized telegraph models) to RNA abundance and live cell imaging data
#

"""
    fit(nchains::Int,gene::String,cell::String,fittedparam::Vector,fixedeffects::Tuple,datatype,datacond,G::Int,maxtime::Float64,infolder::String,resultfolder::String,datafolder,runcycle::Bool,inlabel,label,nsets::Int,cv=0.,transient::Bool=false,samplesteps::Int=100000,warmupsteps=20000,annealsteps=100000,temp=1.,tempanneal=100.,root = "/home/carsonc/scrna/",yieldprior = 0.05,ejectprior = 1.0)
    fit(nchains::Int,data::AbstractRNAData,gene::String,cell::String,fittedparam::Vector,fixedeffects::Tuple,datacond,G::Int,maxtime::Float64,infolder::String,resultfolder::String,datafolder,runcycle,inlabel,label,nsets,cv=0.,transient::Bool=false,samplesteps::Int=100000,warmupsteps=20000,annealsteps=100000,temp=1.,tempanneal=100.,root = "/home/carsonc/scrna/",yieldprior = 0.05,ejectprior = 1.0)


Fit steady state or transient GM model to RNA data for a single gene, write the result (through function finalize), and return nothing.

# Arguments
- `nchains`: number of MCMC chains
- `gene`: gene name
- `cell`: cell type
- `datatype`: data type, e.g. genetrap, scRNA, smFISH
- `datacond`: condition, if more than one condition use vector of strings e.g. ["DMSO","AUXIN"]
- `maxtime`: float maximum time for entire run
- `infolder`: folder pointing to results used as initial conditions
- `resultfolder`: folder where results go
- `datafolder`: folder for data, string or array of strings
- `inlabel`: name of input files (not including gene name but including condition)
- `label`: = name of output files
- `nsets`: int number of rate sets
- `runcycle`: if true, cycle through all parameters sequentially in MCMC
- `samplesteps`: int number of samples
- `warmupsteps`: int number of warmup steps
- `annealsteps`: in number of annealing steps
- `temp`: MCMC temperature
- `tempanneal`: starting temperature for annealing
- `root`: root folder of data and Results folders
- `fittedparam`: vector of rate indices,  indices of parameters to be fit (input as string of ints separated by "-")
- `fixedeffects`: (tuple of vectors of rate indices) string indicating which rate is fixed, e.g. "eject"
- `data`: data structure

"""

function fit(nchains::Int,gene::String,cell::String,fittedparam::Vector,fixedeffects::Tuple,transitions::Tuple,datacond,G::Int,R::Int,S::Int,maxtime::Float64,infolder::String,resultfolder::String,datafolder::String,datatype::String,inlabel::String,label::String,nsets::Int,cv=0.,transient::Bool=false,samplesteps::Int=1000000,warmupsteps=0,annealsteps=0,temp=1.,tempanneal=100.,root = ".",priorcv::Float64=10.,decayrate=-1.,burst=true,nalleles=2,optimize=true,type="",rtype="median")
    println(now())
    gene = check_genename(gene,"[")
    printinfo(gene,G,datacond,datafolder,infolder,resultfolder,maxtime)

    resultfolder = folder_path(resultfolder,root,"results",make=true)
    infolder = folder_path(infolder,root,"results")

    if datatype == "genetrap"
        # data = data_genetrap_FISH(root,label,gene)
        # model = model_genetrap(data,gene,transitions,G,R,nalleles,type,fittedparam,fixedeffects,infolder,label,rtype,root)
        data,model = genetrap(root,gene,transitions,G,R,nalleles,type,fittedparam,infolder,resultfolder,label,"median",1.)
    else
        datafolder = folder_path(datafolder,root,"data")
        if occursin("-",datafolder)
            datafolder = string.(split(datafolder,"-"))
        end
        if datatype == "fish"
            fish = true
            yieldprior = 1.
        else
            fish = false
            yieldprior = 0.05
        end
        if occursin("-",datacond)
            datacond = string.(split(datacond,"-"))
        end
        if transient
            data = data_rna(gene,datacond,datafolder,fish,label,["T0","T30","T120"],[0.,30.,120.])
        else
            data = data_rna(gene,datacond,datafolder,fish,label)
        end
        model = model_rna(data,gene,cell,G,cv,fittedparam,fixedeffects,transitions,inlabel,infolder,nsets,root,yieldprior,decayrate,Normal,priorcv,true)
    end
    println("size of histogram: ",data.nRNA)

    options = MHOptions(samplesteps,warmupsteps,annealsteps,maxtime,temp,tempanneal)
    fit(nchains,data,model,options,temp,resultfolder,burst,optimize,root)    # fit(nchains,data,gene,cell,fittedparam,fixedeffects,transitions,datacond,G,maxtime,infolder,resultfolder,datafolder,fish,inlabel,label,nsets,cv,transient,samplesteps,warmupsteps,annealsteps,temp,tempanneal,root,yieldprior,priorcv,decayrate)
end

function fit(nchains,data,model,options,temp,resultfolder,burst,optimize,root)
    print_ll(data,model)
    fit,stats,measures = run_mh(data,model,options,nchains);
    optimized = 0
    if optimize
        try
            optimized = Optim.optimize(x -> lossfnc(x,data,model),fit.parml,LBFGS())
        catch
            @warn "Optimizer failed"
        end
    end
    if burst
        bs = burstsize(fit,model)
    else
        bs = 0
    end
    a = []
    a_ll = []
    for i in 1:size(fit.param)[2]
        param2 = fit.param[:,i]
        r = StochasticGene.get_r(model)
        r[model.fittedparam] = StochasticGene.inverse_transform(param2,model)
        ll_temp = StochasticGene.loglikelihood(param2,data,model)[1]
        push!(a, r)
        push!(a_ll,ll_temp)
    end
    write_ll_sampledrates(a_ll,data,model,root,resultfolder)
    write_sampledrates(a,data,model,root,resultfolder)
    finalize(data,model,fit,stats,measures,temp,resultfolder,optimized,bs,root)
    println(now())
    get_rates(transform(stats.medparam,model),model)
end

lossfnc(x,data,model) = loglikelihood(x,data,model)[1]

"""
burstsize(fit,model::AbstractGMmodel)

Compute burstsize and stats using MCMC chain

"""
function burstsize(fit,model::AbstractGMmodel)
    if model.G > 1
        b = Float64[]
        for p in eachcol(fit.param)
            r = get_rates(p,model)
            push!(b,r[2*model.G-1] / r[2*model.G-2])
        end
        return BurstMeasures(mean(b),std(b),median(b),mad(b), quantile(b,[.025;.5;.975]))
    else
        return 0
    end
end
function burstsize(fit::Fit,model::GRSMmodel)
    if model.G > 1
        b = Float64[]
        L = size(fit.param,2)
        rho = 100/L
        println(rho)
        for p in eachcol(fit.param)
            r = get_rates(p,model)
            if rand() < rho
                push!(b,burstsize(r,model))
            end
        end
        return BurstMeasures(mean(b),std(b),median(b),mad(b), quantile(b,[.025;.5;.975]))
    else
        return 0
    end
end

burstsize(r,model::GRSMmodel) = burstsize(r,model.R,length(model.Gtransitions))

function burstsize(r,R,ntransitions)
    total = min(Int(div(r[ntransitions + 1],r[ntransitions])) * 2,400)
    indices = Indices(collect(ntransitions:ntransitions),collect(ntransitions+1:ntransitions + R + 1 ),[],1)
    M = make_mat_M(make_components_M([(2,1)],2,R,total,0.,2,indices),r)
    nT = 2*2^R
    L = nT*total
    S0 = zeros(L)
    S0[2] = 1.
    s=StochasticGene.time_evolve_diff([1,10/minimum(r[ntransitions:ntransitions+R+1])],M,S0)
    mean_histogram(s[2,collect(1:nT:L)])
end


"""
check_genename(gene,p1)

Check genename for p1
if p1 = "[" change to "("
(since swarm cannot parse "(")

"""
function check_genename(gene,p1)
    if occursin(p1,gene)
        if p1 == "["
            gene = replace(gene,"[" => "(")
            gene = replace(gene,"]" => ")")
        elseif p1 == "("
            gene = replace(gene,"(" => "]")
            gene = replace(gene,")" => "]")
        end
    end
    return gene
end


"""
print_ll(param,data,model,message="initial ll:")

compute and print initial loglikelihood
"""
function print_ll(param,data,model,message)
    ll,_ = loglikelihood(param,data,model)
    println(message,ll)
end
function print_ll(data,model,message="initial ll: ")
    ll,_ = loglikelihood(get_param(model),data,model)
    println(message,ll)
end

"""
printinfo(gene,G,cond,datafolder,infolder,resultfolder,maxtime)

print out run information
"""
function printinfo(gene,G,cond,datafolder,infolder,resultfolder,maxtime)
    println("Gene: ",gene," G: ",G," Treatment:  ",cond)
    println("data: ",datafolder)
    println("in: ", infolder," out: ",resultfolder)
    println("maxtime: ",maxtime)
end

"""
finalize(data,model,fit,stats,waic,temp,resultfolder,optimized,burst,root)

write out run results and print out final loglikelihood and deviance
"""
function finalize(data,model,fit,stats,measures,temp,resultfolder,optimized,burst,root)
    writefolder = joinpath(root,resultfolder)
    writeall(writefolder,fit,stats,measures,data,temp,model,optimized=optimized,burst=burst)
    println("final max ll: ",fit.llml)
    print_ll(transform(vec(stats.medparam),model),data,model,"median ll: ")
    println("Median fitted rates: ",stats.medparam[:,1])
    println("ML rates: ",inverse_transform(fit.parml,model))
    println("Acceptance: ",fit.accept,"/",fit.total)
    println("Deviance: ",deviance(fit,data,model))
    println("rhat: ",maximum(measures.rhat))
    if optimized != 0
        println("Optimized ML: ",Optim.minimum(optimized))
        println("Optimized rates: ",exp.(Optim.minimizer(optimized)))
    end
end


"""
readrates_genetrap(infolder::String,rtype::String,gene::String,label,G,R,nalleles,type::String)

Read in initial rates from previous runs
"""

function read_ratefile


end

function readrates_genetrap(infolder::String,rtype::String,gene::String,label,G,R,nalleles,type::String)
    if rtype == "ml"
        row = 1
    elseif rtype == "mean"
        row = 2
    elseif rtype == "median"
        row = 3
    elseif rtype == "last"
        row = 4
    else
        row = 3
    end
    if type == "offeject" || type == "on"
        type = ""
    end
    infile = getratefile_genetrap(infolder,rtype,gene,label,G,R,nalleles,type)
    println(gene," ","$G$R"," ",label)
    readrates_genetrap(infile,row)
end

function readrates_genetrap(infile::String,row::Int)
    if isfile(infile) && ~isempty(read(infile))
        return readrates(infile,row)
    else
        println(" no prior")
        return 0
    end
end

function getratefile_genetrap(infolder::String,rtype::String,gene::String,label,G,R,nalleles,type::String)
    model = R == 0 ? "$G" : "$G$R"
    file = "rates" * "_" * label * "_" * gene * "_" * model * "_"  * "$(nalleles)" * ".txt"
    joinpath(infolder,file)
end


"""
getr(gene,G,nalleles,decayrate,ejectrate,inlabel,infolder,nsets::Int,root,verbose)

"""
function getr(gene,G,nalleles,decayrate,ejectrate,inlabel,infolder,nsets::Int,root,verbose)
    r = getr(gene,G,nalleles,inlabel,infolder,root,verbose)
    if ~isnothing(r)
        if length(r) == 2*G*nsets + 1
            for n in nsets
                r[2*G*n-1] *= clamp(r[2*G*nsets + 1],eps(Float64),1-eps(Float64))
            end
            r = r[1:2*G*nsets]
        end
        if length(r) == 2*G*nsets
            if verbose
                println("init rates: ",r)
            end
            return r
        end
    end
    println("No r")
    setr(G,nsets,decayrate,ejectrate)
end

function getr(gene,G,nalleles,inlabel,infolder,root,verbose)
    ratefile = path_Gmodel("rates",gene,G,nalleles,inlabel,infolder,root)
    if verbose
        println("rate file: ",ratefile)
    end
    if isfile(ratefile)
        r = readrates(ratefile,2)
    else
        return nothing
    end
end
function getcv(gene,G,nalleles,fittedparam,inlabel,infolder,root,verbose = true)
    paramfile = path_Gmodel("param-stats",gene,G,nalleles,inlabel,infolder,root)
    if isfile(paramfile)
        cv = read_covlogparam(paramfile)
        cv = float.(cv)
        if ~ isposdef(cv) || size(cv)[1] != length(fittedparam)
            cv = .02
        end
    else
        cv = .02
    end
    if verbose
        println("cv: ",cv)
    end
    return cv
end
"""
    get_decay(gene::String,cell::String,root::String,col::Int=2)
    get_decay(gene::String,path::String,col::Int)

    Get decay rate for gene and cell

"""
function get_decay(gene::String,cell::String,root::String,col::Int=2)
    path = get_file(root,"data/halflives",cell,"csv")
    if isnothing(path)
        println(gene," has no decay time")
        return -1.
    else
        get_decay(gene,path,col)
    end
end
function get_decay(gene::String,path::String,col::Int)
    a = nothing
    in = readdlm(path,',')
    ind = findfirst(in[:,1] .== gene)
    if ~isnothing(ind)
        a = in[ind,col]
    end
    get_decay(a,gene)
end
function get_decay(a,gene::String)
    if typeof(a) <: Number
        return get_decay(float(a))
    else
        println(gene," has no decay time")
        return -1.
    end
end
get_decay(a::Float64) = log(2)/a/60.

"""
    alleles(gene::String,cell::String,root::String,col::Int=3)
    alleles(gene::String,path::String,col::Int=3)

    Get allele number for gene and cell
"""
function alleles(gene::String,cell::String,root::String;nalleles::Int=2,col::Int=3)
    path = get_file(root,"data/alleles",cell,"csv")
    if isnothing(path)
        return 2
    else
        alleles(gene,path,nalleles=nalleles,col=col)
    end
end

function alleles(gene::String,path::String;nalleles::Int=2,col::Int=3)
    a = nothing
    in,h = readdlm(path,',',header=true)
    ind = findfirst(in[:,1] .== gene)
    if isnothing(ind)
        return nalleles
    else
        a = in[ind,col]
        return isnothing(a) ? nalleles : Int(a)
    end
end
