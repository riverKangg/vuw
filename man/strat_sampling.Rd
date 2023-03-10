% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sampling.R
\name{strat_sampling}
\alias{strat_sampling}
\title{Stratified Sampling}
\usage{
strat_sampling(
  df,
  group_var,
  size,
  replace = TRUE,
  contain0 = FALSE,
  verbose = TRUE,
  method = c("round", "floor", "ceiling"),
  seed
)
}
\arguments{
\item{df}{data.table object}

\item{group_var}{group variable}

\item{size}{sampling size}

\item{replace}{replacement}

\item{verbose}{messages}

\item{method}{approximation method}

\item{seed}{random seed}

\item{zero}{non-sampling}
}
\description{
Common stratified sampling technique
}
