# Functions for creating batch files to run on NIH Biowulf super computer

using DelimitedFiles

transientgenelist = ["MYC", "DUSP5", "TRIB1", "PMAIP1", "SERPINE1", "SOX9", "ERRFI1", "NR4A2", "JUN", "GEM"]


function makeswarm(G::Int,infolder,swarmfile::String,inlabel,label,nsets,datafolder::String;thresholdlow::Float64=0.,thresholdhigh::Float64=100000000.,conds::String="DMSO-AUXIN",result::String= "2021-03-11",batchsize=1000,maxtime = 3600. * 2,nchains::Int = 2,runcycle::Bool=true,transient::Bool=false,fittedparam::String="",fixedeffects::String="",juliafile::String="/home/carsonc/StochasticGene/runfiles/fitscript.jl",root="/home/carsonc/scrna/")
    if occursin.("-",conds)
        cond = string.(split(conds,"-"))[1]
    else
        cond = conds
    end
    genes = checkgenes(root,cond,datafolder,thresholdlow,thresholdhigh)
    makeswarm(genes,G,infolder,swarmfile,inlabel,label,nsets,datafolder,conds=conds,result=result,batchsize=batchsize,maxtime=maxtime,nchains=nchains,runcycle=runcycle,transient=transient,fittedparam=fittedparam,fixedeffects=fixedeffects,juliafile=juliafile,root=root)
end

function makeswarm(genes::Vector,G::Int,infolder,swarmfile::String,inlabel,label,nsets,datafolder::String;conds::String="DMSO-AUXIN",result::String="testout",batchsize=1000,maxtime=60.,nchains::Int=2,runcycle::Bool=true,transient::Bool=false,fittedparam::String="",fixedeffects="",juliafile::String="/home/carsonc/StochasticGene/runfiles/fitscript.jl",root="/home/carsonc/scrna/")

    resultfolder = joinpath("Results",result)
    infolder = joinpath("Results",infolder)
    ngenes = length(genes)
    println(ngenes)
    println(runcycle)

    if ngenes > batchsize
        nbatches = div(ngenes,batchsize)
        batches = Vector{Vector{String}}(undef,nbatches+1)
        println(batchsize," ",nbatches)
        for i in 1:nbatches
            batches[i] = genes[batchsize*(i-1)+1:batchsize*(i)]
        end
        batches[end] = genes[batchsize*nbatches+1:end]
        for batch in eachindex(batches)
            sfile = swarmfile * "_" * conds * "$batch" * ".swarm"
            writegenes(sfile,batches[batch],nchains,juliafile,conds,G,maxtime,infolder,resultfolder,datafolder,inlabel,label,nsets,runcycle,transient,nchains,fittedparam,fixedeffects)
        end
    else
        sfile = swarmfile * "_" * conds * ".swarm"
        f = open(sfile,"w")
        writegenes(sfile,genes,nchains,juliafile,conds,G,maxtime,infolder,resultfolder,datafolder,inlabel,label,nsets,runcycle,transient,nchains,fittedparam,fixedeffects)
    end
end

function getbatches(genes,ngenes,batchsize)
    nbatches = div(ngenes,batchsize)
    batches = Vector{Vector{String}}(undef,nbatches+1)
    println(batchsize," ",nbatches)
    for i in 1:nbatches
        batches[i] = genes[batchsize*(i-1)+1:batchsize*(i)]
    end
    batches[end] = genes[batchsize*nbatches+1:end]
    return batches
end

function writegenes(sfile,genes,nprocs,juliafile,cond,G,maxtime,infolder,resultfolder,datafolder,inlabel,label,nsets,runcycle,transient,nchains,fittedparam,fixedeffects)
    f = open(sfile,"w")
    for gene in genes
        writedlm(f,["julia -p" nprocs juliafile gene cond G maxtime infolder resultfolder datafolder inlabel label nsets runcycle transient nchains fittedparam fixedeffects])
    end
    close(f)
end


# function checkgenes(cond,datafolder,thresholdlow,thresholdhigh,root = "/Users/carsonc/Box/scrna",halflives="data/HCT116_all_cells_histograms_and_half_lives_March_2021/Starved_Rep7_half_lives.csv")
#     datapath = joinpath(root,datafolder)
#     # genes = readdlm(joinpath(root,"data/HCT_HEK_Half_life_top_below_1h.csv"),',')[2:end,end]
#     hlfile = joinpath(root,halflives)
#     contents = readdlm(joinpath(root,"data/HCT116_all_cells_histograms_and_half_lives_March_2021/Starved_Rep7_half_lives.csv"),',')
#     genedecay = contents[2:end,2]
#     genenames = contents[2:end,1]
#     genes1 = Vector{String}(undef,0)
#     for i in eachindex(genedecay)
#         if typeof(genedecay[i]) <: Number
#             if thresholdlow <= genedecay[i] < thresholdhigh
#                 push!(genes1,genenames[i])
#             end
#         end
#     end
#     println(length(genes1))
#     genes2 = readdlm(joinpath(root,"data/HCT116_alleles_number.txt"))[2:end,1]
#     println(length(genes2))
#     genes = intersect(genes1,genes2)
#     complement = setdiff(genes1,genes2)
#     println(length(genes))
#     println(length(complement))
#     list = Vector{String}(undef,0)
#     for gene in genes
#         if cond == ""
#             datafile = joinpath(datapath,gene * ".txt")
#         else
#             datafile = joinpath(datapath,gene * "_" * cond * ".txt")
#         end
#         if isfile(datafile)
#             push!(list,gene)
#         end
#     end
#     println(length(list))
#     return list
# end
#
#
# function checkgenes(cond,datafolder,root = "/Users/carsonc/Box/scrna")
#     datapath = joinpath(root,datafolder)
#     # genes = readdlm(joinpath(root,"data/HCT_HEK_Half_life_top_below_1h.csv"),',')[2:end,end]
#     genedecay = readdlm(joinpath(root,"data/HCT116_all_cells_histograms_and_half_lives_March_2021/Starved_Rep7_half_lives.csv"),',')
#     # genes1 = readdlm(joinpath(root,"data/HCT116_all_cells_histograms_and_half_lives_March_2021/Starved_Rep7_half_lives.csv"),',')[2:end,1]
#     genes1 = Vector{String}(undef,0)
#     for i in eachindex(genedecay[2:end,2])
#         if typeof(genedecay[i,2]) <: Number
#             push!(genes1,genedecay[i,1])
#         end
#     end
#     genes2 = readdlm(joinpath(root,"data/HCT116_alleles_number.txt"))[2:end,1]
#     println(length(genes1))
#     println(length(genes2))
#     genes = intersect(genes1,genes2)
#     list = Vector{String}(undef,0)
#     for gene in genes
#         datafile = joinpath(datapath,gene * "_" * cond * ".txt")
#         if isfile(datafile)
#             push!(list,gene)
#         end
#     end
#     println(length(list))
#     return list
# end
#
# function checkgenes(datafolder,root)
#     datapath = joinpath(root,datafolder)
#     genedecay = readdlm(joinpath(root,"data/HCT116_all_cells_histograms_and_half_lives_March_2021/Starved_Rep7_half_lives.csv"),',')
#     genes1 = Vector{String}(undef,0)
#     for i in eachindex(genedecay[2:end,2])
#         if typeof(genedecay[i,2]) <: Number
#             push!(genes1,genedecay[i,1])
#         end
#     end
#     genes2 = readdlm(joinpath(root,"data/HCT116_alleles_number.txt"))[2:end,1]
#     println(length(genes1))
#     println(length(genes2))
#     genes = intersect(genes1,genes2)
#     list = Vector{String}(undef,0)
#     for gene in genes
#         datafile = joinpath(datapath,gene * ".txt")
#         if isfile(datafile)
#             push!(list,gene)
#         end
#     end
#     println(length(list))
#     return list
# end



function checkgenes(root,cond,datafolder,thresholdlow::Float64=0.,thresholdhigh::Float64=1e8,hlfile="data/HCT116_all_cells_histograms_and_half_lives_March_2021/Starved_Rep7_half_lives.csv",allelefile="data/HCT116_alleles_number.txt")
    genes = intersect(get_halflives(root,hlfile,thresholdlow,thresholdhigh), get_genes(root,cond,datafolder))
    if allelefile != ""
        return intersect(genes,get_alleles(root,allelefile))
    else
        return genes
    end
end

function get_genes(root,cond,datafolder)
    genes = Vector{String}(undef,0)
    files = readdir(joinpath(root,datafolder))
    for file in files
        if occursin(cond,file)
            push!(genes,split(file,"_")[1])
        end
    end
    return genes
end

function get_halflives(root,file,thresholdlow=0,thresholdhigh=1e8)
    genes = Vector{String}(undef,0)
    file = joinpath(root,file)
    halflives = readdlm(file,',')
    for row in eachrow(halflives)
        if typeof(row[2]) <: Number
            if thresholdlow <= row[2] < thresholdhigh
                push!(genes,string(row[1]))
            end
        end
    end
    return genes
end

get_alleles(root,allelefile = "data/HCT116_alleles_number.txt") = readdlm(joinpath(root,allelefile))[2:end,1]


fix(folder) = writeruns(fixruns(findjobs(folder)))


function findjobs(folder)
    files = readdir(folder)
    files = files[occursin.("swarm_",files)]
    for (i,file) in enumerate(files)
        files[i] = split(file,"_")[2]
    end
    unique(files)
end

function fixruns(jobs,message="FAILED")
    runlist = Vector{String}(undef,0)
    for job in jobs
        if occursin(message,read(`jobhist $job`,String))
            swarmfile = findswarm(job)
            list = readdlm(swarmfile,',')
            runs =  chomp(read(pipeline(`jobhist $job`, `grep $message`),String))
            runs = split(runs,'\n')
            println(job)
            for run in runs
                linenumber = parse(Int,split(split(run," ")[1],"_")[2])
                a = String(list[linenumber+1])
                println(a)
                push!(runlist,a)
            end
        end
    end
    return runlist
end

function writeruns(runs,outfile="fitfix.swarm")

    f = open(outfile,"w")
    for run in runs
        writedlm(f,[run],quotes=false)
    end
    close(f)

end

function findswarm(job)
    sc = "Swarm Command"
    line = read(pipeline(`jobhist $job`, `grep $sc`),String)
    list = split(line," ")
    list[occursin.(".swarm",list)][1]
end

function collate(folders,type="rates_scRNA_T120")
    genes = Vector{Vector}(undef,0)
    for folder in folders
        files = readdir(folder)
        for file in files
            if occursin(type,file)
                contents=readdlm(file,',')
                for row in eachrow(contents)
                    row[1] .== genes
                end
            end
        end
    end
end

large_deviance(measurefile,threshold) = filter_gene(measurefile,"Deviance",threshold)

function filter_gene(measurefile,measure,threshold)
    genes = Vector{String}(undef,0)
    measures,header = readdlm(measurefile,',',header=true)
    println(length(measures[:,1]))
    col = findfirst(header[1,:] .== measure)
    for d in eachrow(measures)
        if d[col] > threshold || isnan(d[col])
            push!(genes,d[1])
        end
    end
    println(length(genes))
    return genes
end

function filter_gene_nan(measurefile,measure)
    genes = Vector{String}(undef,0)
    measures,header = readdlm(measurefile,',',header=true)
    println(length(measures[:,1]))
    col = findfirst(header[1,:] .== measure)
    for d in eachrow(measures)
        if isnan(d[col])
            push!(genes,d[1])
        end
    end
    println(length(genes))
    return genes
end

function get_missing_genes(folder,type,label,cond,model)
    genes = checkgenes("DMSO",folder,0.,100000000.,"../")
    genes1=StochasticGene.getgenes(folder,type,label,cond,model)
    union(setdiff(genes1,genes),setdiff(genes,genes1))
end

function get_missing_genes(genes,folder,type,label,cond,model)
    genes1=StochasticGene.getgenes(folder,type,label,cond,model)
    union(setdiff(genes1,genes),setdiff(genes,genes1))
end

function scan_swarmfiles(jobid,folder=".")
    if ~(typeof(jobid) <: String)
        jobid = string(jobid)
    end
    genes = Array{String,1}(undef,0)
    files = readdir(folder)
    files = files[occursin.(jobid,files)]
    for file in files
        genes = vcat(genes,scan_swarmfile(file))
    end
    return genes
end

function scan_swarmfile(file)
    genes = Array{String,1}(undef,0)
    contents = readdlm(file,'\t')
    lines = contents[occursin.("[\"",string.(contents))]
    for line in lines
        push!(genes,split.(string(line)," ")[1])
    end
    return genes
end

function scan_fitfile(file,folder=".")
    genes = Array{String,1}(undef,0)
    joinpath(folder,file)
    file = readdlm(file,'\t')
    for line in eachrow(file)
        push!(genes,line[4])
    end
    return genes
end

function replace_yield(G,folder1,folder2,cond1,cond2,outfolder)
    if typeof(G) <: Number
        G = string(G)
    end
    if ~isdir(outfolder)
        mkpath(outfolder)
    end
    files1 = getratefile(folder1,G,cond1)
    files2 = getratefile(folder2,G,cond2)
    for file1 in files1
        gene = StochasticGene.getgene(file1)
        file2 = getratefile(files2,gene)
        outfile = joinpath(outfolder,file2)
        r1 = StochasticGene.readrates(joinpath(folder1,file1))
        r2 = StochasticGene.readrates(joinpath(folder2,file2))
        r2[end] = r1[end]
        f = open(outfile,"w")
        writedlm(f,[r2],',')
        close(f)
    end

end

"""
assemble_r(G,folder1,folder2,cond1,cond2,outfolder)

Combine rates from two separate fits into a single rate vector

"""

function assemble_r(G,folder1,folder2,cond1,cond2,outfolder)
    if typeof(G) <: Number
        G = string(G)
    end
    if ~isdir(outfolder)
        mkpath(outfolder)
    end
    files1 = getratefile(folder1,G,cond1)
    files2 = getratefile(folder2,G,cond2)
    for file1 in files1
        gene = StochasticGene.getgene(file1)
        file2 = getratefile(files2,gene)
        if file2 != 0
            file2=joinpath(folder2,file2)
        else
            file2=joinpath(folder1,file1)
        end
        name = replace(file1, cond1 => cond1 * "-" * cond2)
        outfile = joinpath(outfolder,name)
        assemble_r(joinpath(folder1,file1),file2,outfile)
    end
end


function  assemble_r(ratefile1,ratefile2,outfile)
    r1 = StochasticGene.readrates(ratefile1,2)
    r2 = StochasticGene.readrates(ratefile2,2)
    r1[end] = clamp(r1[end],eps(Float64),1-eps(Float64))
    r = vcat(r1[1:end-1],r2[1:end-1],r1[end])
    f = open(outfile,"w")
    writedlm(f,[r],',')
    writedlm(f,[r],',')
    writedlm(f,[r],',')
    writedlm(f,[r],',')
    close(f)
end

function assemble_r(gene,G,folder1,folder2,cond1,cond2,outfolder)
    file1 = getratefile(gene,G,folder1,cond1)[1]
    file2 = getratefile(gene,G,folder2,cond2)[1]
    name = replace(file1, cond1 => cond1 * "-" * cond2)
    println(name)
    outfile = joinpath(outfolder,name)
    println(outfile)
    assemble_r(joinpath(folder1,file1),joinpath(folder2,file2),outfile)
end


function getratefile(files,gene)
    files = files[occursin.("_"*gene*"_",files)]
    if length(files) > 0
        return files[1]
    else
        # println(gene)
        return 0
    end
end

function getratefile(folder,G,cond)
    files = readdir(folder)
    files = files[occursin.("rates_",files)]
    files = files[occursin.("_"*cond*"_",files)]
    files[occursin.("_"*G*"_",files)]
end


getratefile(gene,G,folder,cond) = getfile("rate",gene,G,folder,cond)

function getfile(type,gene::String,G::String,folder,cond)
    files = readdir(folder)
    files = files[occursin.(type,files)]
    files = files[occursin.("_"*gene*"_",files)]
    files = files[occursin.("_"*G*"_",files)]
    files[occursin.("_"*cond*"_",files)]
end


function change_name(folder,oldname,newname)
    files = readdir(folder)
    files = files[occursin.(oldname,files)]
    for file in files
        newfile = replace(file, oldname => newname)
        mv(joinpath(folder,file),joinpath(folder,newfile),force=true)
    end
end

function make_halflife(infile,outfile,col=4)
    f = open(outfile,"w")
    writedlm(f,["Gene" "Halflife"],',')
    contents,rows = readdlm(infile,',',header=true)
    for row = eachrow(contents)
        gene = string(row[1])
        gene = strip(gene,'*')
        h1 = float(row[col])
        h2 = float(row[col+1])
        if h1 > 0 || h2 > 0
            h = (h1 + h2)/(float(h1>0) + float(h2>0))
            writedlm(f,[gene h],',')
        end
    end
    nothing
end

function make_datafiles(infolder,outfolder,label)
    histograms = readdir(infolder)
    if ~isdir(outfolder)
        mkpath(outfolder)
    end
    for file in histograms
        newfile = replace(file,label => "")
        cp(joinpath(infolder,file),joinpath(outfolder,newfile))
    end
end

function make_dataframe(folder::String,winners::String = "")
    rs = Array{Any,2}(undef,0,8)
    files =readdir(folder)
    n = 0
    for file in files
        if occursin("rate",file)
            t = parse(Float64,split(split(file,"T")[2],"_")[1])
            r,head = readdlm(joinpath(folder,file),',',header=true)
            r = [vcat(r[:,[1,2,3,4,5,10]], r[:,[1,6,7,8,9,10]])  [zeros(size(r)[1]); ones(size(r)[1])]  t*ones(2*size(r)[1])/60.]
            rs = vcat(rs,r)
            n += 1
        end
    end
    if winners != ""
        w = get_winners(winners,2*n)
        return DataFrame(Gene = rs[:,1],on = float.(rs[:,2]),off=float.(rs[:,3]),eject=float.(rs[:,4]),decay=float.(rs[:,5]),yield=float.(rs[:,6]),cond = Int.(rs[:,7]),time = float.(rs[:,8]),winner = w)
    else
        return DataFrame(Gene = rs[:,1],on = float.(rs[:,2]),off=float.(rs[:,3]),eject=float.(rs[:,4]),decay=float.(rs[:,5]),yield=float.(rs[:,6]),cond = Int.(rs[:,7]),time = float.(rs[:,8]))
    end
end

function get_winners(winners::String,n::Int)
    m,h = readdlm(winners,',',header=true)
    winner = repeat(m[:,end],n)
end
