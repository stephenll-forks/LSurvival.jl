module LSurvival
####### imports #######

using Reexport
using Printf
using Random, Distributions, LinearAlgebra, Tables
@reexport using StatsModels # ModelFrame, modelframe
#
#import DataFrames: DataFrame
using StatsBase
import StatsBase: CoefTable, StatisticalModel, RegressionModel
import Base: length, size, popat!, push!

import StatsBase:
    aic,
    aicc,
    bic,
    coef,
    coeftable,
    coefnames,
    confint,
    deviance,
    nulldeviance, #, dof_residual,
    dof,
    fitted,
    fit,
    isfitted,
    loglikelihood,
    #lrtest,
    modelmatrix,
    model_response,
    nullloglikelihood,
    nobs,
    PValue,
    stderror,
    residuals,
    #predict, predict!,
    response,
    score,
    vcov,
    weights

import Base: convert, show

####### exports #######

# Structs
export AbstractPH,
    AbstractNPSurv,
    AbstractLSurvivalID,
    AbstractLSurvivalParms,
    AbstractSurvTime,
    AJSurv,
    ID,
    KMSurv,
    LSurvivalResp,
    LSurvivalCompResp,
    PHModel,
    PHParms,
    PHSurv,
    # Strata
    Surv

# functions    
export kaplan_meier,        # interface for estimating cumulative risk from non-parametric estimator
    aalen_johansen,        # interface for estimating cumulative risk from non-parametric competing risk estimator
    coxph,                 # interface for Cox model
    risk_from_coxphmodels,  # interface for estimating cumulative risk from hazard specific Cox models
    # deprecated
    coxmodel,            # (deprecated) interface for Cox model
    cox_summary,         # (deprecated) convenience function to summarize Cox model results
    ci_from_coxmodels    # (deprecated) interface for estimating cumulative risk from hazard specific Cox models
#re-exports
export aic,
    aicc,
    bic,
    bootstrap,
    basehaz!,
    coef,
    coeftable,
    coefnames,
    confint,
    nulldeviance,
    deviance,
    dof,
    fit,
    fit!,
    model_response,
    modelmatrix, #PValue
    fitted,
    isfitted,
    jackknife,
    loglikelihood,
    logpartiallikelihood,
    lrtest, # re-exported
    modelmatrix,
    length,
    size,
    nullloglikelihood,
    nulllogpartiallikelihood,
    nobs,
    response,
    score,
    stderror,
    residuals,
    #predict, predict!,
    vcov,
    weights

####### Documentation #######
include("docstr.jl")


####### Abstract types #######

"""
$DOC_ABSTRACTLSURVRESP
"""
abstract type AbstractLSurvivalResp end

"""
$DOC_ABSTRACTLSURVPARMS
"""
abstract type AbstractLSurvivalParms end

"""
$DOC_ABSTRACTPH
"""
abstract type AbstractPH <: RegressionModel end   # model based on a linear predictor

"""
$DOC_ABSTRACTNPSURV
"""
abstract type AbstractNPSurv end

####### function definitions #######

include("shared_structs.jl")
include("coxmodel.jl")
include("residuals.jl")
include("npsurvival.jl")
include("data_generators.jl")
include("bootstrap.jl")
include("jackknife.jl")
include("deprecated.jl")



end