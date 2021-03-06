% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/modeldetails_module.R
\name{modeldetailsUI}
\alias{modeldetailsUI}
\alias{modeldetails}
\title{modeldetailsUI}
\usage{
modeldetailsUI(id)

modeldetails(input, output, session, modelID, portfolioID, file_pins,
  counter, active = reactive(TRUE))
}
\arguments{
\item{id}{module id}

\item{input, output, session}{Shiny input, output, and session objects.}

\item{modelID}{Selected model ID.}

\item{portfolioID}{Selected portfolio ID.}

\item{file_pins}{file with coordiantes of exposure locations}

\item{counter}{Reactive value to trigger inputs download.}

\item{active}{reactive expression whether the module state should be updated.}

\item{id}{Namespace ID for the module.}
}
\description{
UI side of function wrapping panel to show model details.

Server side of function wrapping panel to show analyses details table.
}
