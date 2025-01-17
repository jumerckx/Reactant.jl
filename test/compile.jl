using Reactant
using Test

Base.sum(x::NamedTuple{(:a,),Tuple{T}}) where {T<:Reactant.TracedRArray} = (; a=sum(x.a))

@testset "compile" begin
    @testset "create_result" begin
        @testset "NamedTuple" begin
            x = (; a=rand(4, 3))
            x2 = Reactant.to_rarray(x)

            res = @jit sum(x2)
            @test res isa @NamedTuple{a::Reactant.ConcreteRNumber{Float64}}
            @test isapprox(res.a, sum(x.a))
        end
    end

    @testset "world-age" begin
        a = ones(2, 10)
        b = ones(10, 2)
        a_ra = Reactant.ConcreteRArray(a)
        b_ra = Reactant.ConcreteRArray(b)

        fworld(x, y) = @jit(x * y)

        @test fworld(a_ra, b_ra) ≈ ones(2, 2) * 10
    end

    @testset "type casting & optimized out returns" begin
        a = ones(2, 10)
        a_ra = Reactant.ConcreteRArray(a)

        ftype1(x) = Float64.(x)
        ftype2(x) = Float32.(x)

        y1 = @jit ftype1(a_ra)
        y2 = @jit ftype2(a_ra)

        @test y1 isa Reactant.ConcreteRArray{Float64,2}
        @test y2 isa Reactant.ConcreteRArray{Float32,2}

        @test y1 ≈ Float64.(a)
        @test y2 ≈ Float32.(a)
    end

    # disabled due to long test time (core tests go from 2m to 7m just with this test)
    # @testset "resource exhaustation bug (#190)" begin
    #     x = rand(2, 2)
    #     y = Reactant.to_rarray(x)
    #     @test try
    #         for _ in 1:10_000
    #             f = @compile sum(y)
    #         end
    #         true
    #     catch e
    #         false
    #     end
    # end
end
