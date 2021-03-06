% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/oasisuiIncrementalPanel.R
\name{callIncrementalPanelModules}
\alias{callIncrementalPanelModules}
\title{callIncrementalPanelModules}
\usage{
callIncrementalPanelModules(IDs, ID_0, contentIDs, contentUI,
  headings = NULL, collapsible = FALSE, show = TRUE, ns = identity)
}
\arguments{
\item{IDs}{Character vector of IDs to be used for the content of
each panel upon its creation.}

\item{ID_0}{Character string with the ID of an existing initial panel.}

\item{contentIDs}{Character vector of IDs to be used for the content of
each panel upon its creation.}

\item{contentUI}{Function used to populate any new panel.}

\item{headings}{Heading content to be used for each panel upon its
creation, as a character vector or list.}

\item{collapsible}{Logical flag specifying if the panel is collapsible.}

\item{show}{Logical flag specifying if a collapsible panel should be
initially shown as not collapsed.}

\item{ns}{Namespace function, typically obtained via \code{\link[shiny:NS]{shiny::NS()}}.}
}
\value{
A \code{list} with components:
\itemize{
\item \code{$state}: The reactive state of the panels (see
\code{\link[=oasisuiIncrementalPanel]{oasisuiIncrementalPanel()}}).
\item \code{$remove_all}: A Function to remove all panels.
}
}
\description{
This is a convenience wrapper to enable the server logic of a number of
\link{oasisuiIncrementalPanel}s, returning their reactive state and a function to
remove them all.
}
\examples{
if (interactive()) {
  library(shiny)
  n_panels <- 10L
  # Example module
  examplePanelUI <- function(id) {
    ns <- NS(id)
    verticalLayout(
      textInput(ns("txt_in"), label = paste("type something", id)),
      textOutput(ns("txt_out")),
      actionButton(ns("upd"), "Update")
    )
  }
  examplePanel <- function(input, output, session, reset = reactive(FALSE)) {
    txt <- reactiveVal(NULL)
    observe({
      reset()
      txt(NULL)
    })
    observeEvent(input$upd, txt(input$txt_in))
    output$txt_out <- renderText(txt())
    reactive(txt())
  }
  ui <- fluidPage(
    tags$style(HTML('
                    .collapsebtn:after {
                    font-family: "Font Awesome 5 Free"; font-weight: 900; content: "\\\\f068";
                    float: right;
                    }
                    .collapsebtn.collapsed:after {
                    content: "\\\\f31e";
                    }
                    ')),
    titlePanel("Dynamic panels"),
    verticalLayout(
      actionButton("delete_all", "Remove all panels"),
      oasisuiIncrementalPanelUI(
        "start-panel", heading = "Add a new panel",
        collapsible = FALSE, show = FALSE, removable = FALSE
      )
    )
  )
  server <- function(input, output, session) {
    # NOTE that, since we are using server logic to create UI elements, the IDs
    # used for the UI components must include session$ns (relevant for module
    # server functions)
    ns <- session$ns
    panel_IDs <- paste0("extpanel-", seq_len(n_panels))
    # content IDs used for the content module server and UI
    # content modules
    content_IDs <- paste0("content-", seq_len(n_panels))
    all_panels <- callIncrementalPanelModules(
      panel_IDs, "start-panel", content_IDs,
      examplePanelUI,
      headings = lapply(seq_len(n_panels), function(i) {
        oasisuiPanelHeadingOutput(ns(paste0("paneltitle", i)))
      }),
      collapsible = TRUE, show = TRUE,
      ns = ns
    )
    panel_modules <- lapply(seq_len(n_panels), function(i) {
      callModule(examplePanel, content_IDs[i], reactive(all_panels$state[[ns(panel_IDs[i])]]))
    })
    lapply(seq_along(panel_modules), function(i) {
      output[[paste0("paneltitle", i)]] <- renderOasisuiPanelHeading(panel_modules[[i]]())
    })
    observeEvent(input$delete_all, {
      all_panels$remove_all()
    })
  }

  shinyApp(ui = ui, server = server)

}
}
