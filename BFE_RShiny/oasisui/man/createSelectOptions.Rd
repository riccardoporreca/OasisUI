% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/shiny.R
\name{createSelectOptions}
\alias{createSelectOptions}
\title{createSelectOptions}
\usage{
createSelectOptions(df, label = NA, value = "0", labelCol = 2,
  valueCol = 1)
}
\arguments{
\item{df}{\code{data.frame}.}

\item{label}{Label for extra option to add at the top. If \code{NA} (default)
no extra option will be added to the top.}

\item{value}{value for extra option to add at the top.}

\item{labelCol}{Column index of the column that is used for the labels.}

\item{valueCol}{Column index of the column that is used for the values.}
}
\value{
smth.
}
\description{
Converts a table into a named list of choices for use in
\link{selectInput}.
}
