using StochasticGene
using Test

function fit_rna_test(root=".")
    gene = "CENPL"
    cell = "HCT116"
    fish = false
    nalleles = 2
    r = [0.01, 0.1, 1.0, 0.01006327034802035]
    decayrate = 0.01006327034802035
    model = StochasticGene.model_rna(r,2,nalleles,1,.01,[1,2,3],(),decayrate,.05)
    data = StochasticGene.data_rna(gene,"MOCK","data/HCT116_testdata",fish,"scRNA_test",root)
    options = StochasticGene.MHOptions(100000,0,0,0,120.,1.,100.)
    fit,stats,measures = StochasticGene.run_mh(data,model,options,1);
    return stats.meanparam, fit.llml, model
end

function teststeadystatemodel(r,G,nhist,nalleles)
    g1 = StochasticGene.steady_state(r[1:2*G],G-1,nhist,nalleles)
    g2 = StochasticGene.simulatorGM(r[1:2*G],G-1,nhist,nalleles)
    return g1, g2
end


@testset "StochasticGene" begin

        p,ll,model =  fit_rna_test()
        @test isapprox(ll,1766,rtol=0.05)

        r = [0.0014, 0.005, 0.0016, 0.01]
        h1,h2 = teststeadystatemodel(r,2,60,2)

        @test isapprox(h1,h2,rtol=0.05)

end
