% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/batchAna_server.R, R/batchAna_ui.R
\name{batchAna}
\alias{batchAna}
\alias{batchAnaUI}
\title{batchAna}
\usage{
batchAna(input, output, session, active = reactive(TRUE))

batchAnaUI(id)
}
\arguments{
\item{input, output, session}{Shiny input, output, and session objects.}

\item{active}{reactive expression whether the module state should be updated.}

\item{id}{Namespace ID for the module.}
}
\value{
The returned list also includes reactive navigation state
constructed via \code{\link[=outputNavigation]{outputNavigation()}}.

List of tags.
}
\description{
Server logic to define a batch analysis.

UI/View to define a batch analysis.
}
