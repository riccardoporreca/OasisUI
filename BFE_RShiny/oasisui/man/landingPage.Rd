% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/landingpage_module.R
\name{landingPageUI}
\alias{landingPageUI}
\alias{landingPage}
\title{landingPage}
\usage{
landingPageUI(id)

landingPage(input, output, session, active = reactive(TRUE))
}
\arguments{
\item{id}{Namespace ID for the module.}

\item{input, output, session}{Shiny input, output, and session objects.}

\item{active}{reactive expression whether the module state should be updated.}
}
\value{
List of tags.

The returned list also includes reactive navigation state
constructed via \code{\link[=outputNavigation]{outputNavigation()}}.

anaID id of selected analysis
}
\description{
landingPage

Landing Page
}
