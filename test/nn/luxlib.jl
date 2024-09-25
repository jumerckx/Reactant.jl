using LuxLib, Reactant, Enzyme, NNlib

@testset "Fused Dense" begin end

@testset "Bias Activation" begin
end

@testset "Fast Activation" begin
    # Here we are testing that fast_activation doesn't switch to the faster versions
    sumabs2(f, x) = sum(abs2, fast_activation(f, x))
    sumabs2!!(f, x) = sum(abs2, fast_activation!!(f, copy(x)))

    function ∇sumabs2(f, x)
        dx = Enzyme.make_zero(x)
        Enzyme.autodiff(Reverse, sumabs2, Active, Const(f), Duplicated(x, dx))
        return dx
    end

    function ∇sumabs2!!(f, x)
        dx = Enzyme.make_zero(x)
        Enzyme.autodiff(Reverse, sumabs2, Active, Const(f), Duplicated(x, dx))
        return dx
    end

    x_act = randn(Float32, 10, 10)
    x_act_ca = Reactant.ConcreteRArray(x_act)

    @testset "Activation: $act" for act in (
        identity, relu, sigmoid, tanh, tanh_fast, sigmoid_fast, gelu, abs2
    )
        f_compile = Reactant.compile(sumabs2, (act, x_act))
        f_compile!! = Reactant.compile(sumabs2!!, (act, x_act))

        y_simple = sumabs2(act, x_act)
        y_simple!! = sumabs2!!(act, x_act)
        y_compile = f_compile(act, x_act_ca)
        y_compile!! = f_compile!!(act, x_act_ca)

        @test y_simple ≈ y_compile
        @test y_simple!! ≈ y_compile!!

        ∂x_enz = Enzyme.make_zero(x_act)
        Enzyme.autodiff(Reverse, sumabs2, Active, Const(act), Duplicated(x_act, ∂x_enz))

        ∂x_enz!! = Enzyme.make_zero(x_act)
        Enzyme.autodiff(Reverse, sumabs2!!, Active, Const(act), Duplicated(x_act, ∂x_enz!!))

        ∇sumabs2_compiled = Reactant.compile(∇sumabs2, (act, x_act_ca))
        ∂x_compile = ∇sumabs2_compiled(act, x_act_ca)

        ∇sumabs2!!_compiled = Reactant.compile(∇sumabs2!!, (act, x_act_ca))
        ∂x_compile!! = ∇sumabs2!!_compiled(act, x_act_ca)

        @test ∂x_enz ≈ ∂x_compile broken = (act === gelu)
        @test ∂x_enz!! ≈ ∂x_compile!! broken = (act === gelu)
    end
end

@testset "Fused Conv" begin
    @testset for groups in (1, 2, 4),
        has_bias in (true, false),
        act in (identity, relu, sigmoid, tanh, gelu)

        weight = randn(Float32, 4, 4, 8 ÷ groups, 4)
        x = randn(Float32, 16, 16, 8, 2)
        bias = has_bias ? randn(Float32, 4) : nothing

        weight_reactant = Reactant.ConcreteRArray(weight)
        x_reactant = Reactant.ConcreteRArray(x)
        bias_reactant = Reactant.to_rarray(bias)

        @testset for stride in ((1, 1), (2, 2), (3, 3)),
            padding in ((0, 0), (1, 1), (2, 2), (0, 2), (2, 0), (0, 1), (1, 0)),
            dilation in ((1, 1), (2, 2), (1, 2), (2, 1))

            conv_dims = DenseConvDims(x, weight; stride, padding, dilation, groups)

            fused_conv_compiled = Reactant.compile(
                fused_conv_bias_activation,
                (act, weight_reactant, x_reactant, bias_reactant, conv_dims),
            )

            reactant_res = fused_conv_compiled(
                act, weight_reactant, x_reactant, bias_reactant, conv_dims
            )
            luxlib_res = fused_conv_bias_activation(act, weight, x, bias, conv_dims)

            @test reactant_res ≈ luxlib_res broken = (act === gelu)
        end

        # TODO: test for gradients
    end
end
