# outputplots Module -----------------------------------------------------------

# UI ---------------------------------------------------------------------------

#' outputplotsUI
#'
#' @rdname outputplots
#'
#' @description UI/View for output plots of a run.
#'
#' @return List of tags.
#'
#' @export
outputplotsUI <- function(id) {

  ns <- NS(id)

  oasisuiIncrementalPanelUI(
    id = ns("oasisuiIncrementalPanelOutput-0"),
    heading = "New plot",
    collapsible = FALSE, show = FALSE, removable = FALSE)

}

# Server -----------------------------------------------------------------------

#' outputplots
#'
#' @rdname outputplots
#'
#' @description Server logic for outputplots of a run.
#'
#' @template params-module
#' @template params-active
#' @param selectAnaID id of selected analysis
#' @param n_panels number of panels
#' @param filesListData Table of output files for a given analysis id
#'
#' @export
outputplots <- function(input, output, session,
                        selectAnaID,
                        n_panels,
                        filesListData = reactive(NULL),
                        active) {

  ns <- session$ns

  # list of sub-modules
  sub_modules <- list()

  #incremental panels -----------------------------------------------------------
  panel_IDs <- paste0("oasisuiIncrementalPanelOutput-", seq_len(n_panels))
  content_IDs <- paste0("oasisuiIncrementalPanelOutputcontent-", seq_len(n_panels))
  plotPanels <- callIncrementalPanelModules(
    panel_IDs, "oasisuiIncrementalPanelOutput-0", content_IDs,
    panelOutputModuleUI,
    headings = lapply(seq_len(n_panels), function(i) {
      oasisuiPanelHeadingOutput(ns(paste0("paneltitle", i)))
    }),
    collapsible = TRUE, show = TRUE, ns = ns
  )
  plotsubmodules <- lapply(seq_len(n_panels), function(i) {
    callModule(panelOutputModule, content_IDs[i],
               filesListData =  reactive(filesListData()),
               anaID = selectAnaID,
               active = reactive(plotPanels$state[[ns(panel_IDs[i])]]))
  })
  lapply(seq_along(plotsubmodules), function(i) {
    output[[paste0("paneltitle", i)]] <- renderOasisuiPanelHeading(plotsubmodules[[i]]())
  })

  observeEvent({
    selectAnaID()
    filesListData()}, {
    plotPanels$remove_all()
  })

  return(invisible())
}


# panelOutputModule Module -----------------------------------------------------

# UI ---------------------------------------------------------------------------
#' panelOutputModuleUI
#'
#' @rdname panelOutputModule
#'
#' @importFrom shinyWidgets panel
#' @importFrom shinyjs hidden
#' @importFrom plotly plotlyOutput
#'
#' @export
panelOutputModuleUI <- function(id){
  ns <- NS(id)

  tagList(
    oasisuiPanel(
      id = ns("oasisuiPanelOutputModule"),
      collapsible = TRUE,
      heading = "Custom plot",
      h4("Data to plot"),
      column(12,
             div( class = "InlineSelectInput",
                  selectInput(inputId = ns("inputplottype"), label = "Select a plot type", choices = names(plottypeslist), selected = names(plottypeslist)[1]))
      ),
      br(),
      column(4,
             checkboxGroupInput(inputId = ns("chkboxgrplosstypes"), label = "Perspective", choices = output_options$losstypes, inline = TRUE)),
      column(8,
             checkboxGroupInput(inputId = ns("chkboxgrpgranularities"), label = "Summary Level", choices = output_options$granularities, inline = TRUE)),
      br(),
      column(12,
             checkboxGroupInput(inputId = ns("chkboxgrpvariables"), label = "Report", choices = output_options$variables, inline = TRUE)),
      br(),
      h4("Customize plot"),
      column(4,
             div(class = "InlineTextInput",
                 textInput(ns("textinputtitle"), "Title", ""))),
      column(4,
             hidden(checkboxInput(ns("chkboxuncertainty"), "Include Uncertainty", FALSE))),
      oasisuiButton(inputId = ns("abuttondraw"), label = "Draw Plot",  style = "float:right")
    ),

    panel(
      # heading = h4("Plot"),
      plotlyOutput(ns("outputplot"))
    )
  )
}

# Server -----------------------------------------------------------------------

#' panelOutputModule
#'
#' @rdname panelOutputModule
#'
#' @description Server logic to show graphical output such as plots.
#'
#' @template params-module
#' @template params-active
#'
#' @param filesListData table of output files for a given anaID
#' @param anaID is selectAnaID
#'
#' @return reactive value of the title
#'
#' @importFrom shinyjs enable
#' @importFrom shinyjs disable
#' @importFrom shinyjs show
#' @importFrom shinyjs hide
#' @importFrom dplyr rename
#' @importFrom dplyr left_join
#' @importFrom dplyr filter
#' @importFrom dplyr intersect
#' @importFrom tidyr gather
#' @importFrom tidyr separate
#' @importFrom tidyr  spread
#' @importFrom ggplot2 geom_line
#' @importFrom ggplot2 geom_hline
#' @importFrom ggplot2 ggplot
#' @importFrom ggplot2 labs
#' @importFrom ggplot2 theme
#' @importFrom ggplot2  aes
#' @importFrom ggplot2 element_text
#' @importFrom ggplot2 element_line
#' @importFrom ggplot2 element_blank
#' @importFrom ggplot2 geom_point
#' @importFrom ggplot2 facet_wrap
#' @importFrom ggplot2 scale_x_continuous
#' @importFrom ggplot2 geom_bar
#' @importFrom ggplot2 geom_errorbar
#' @importFrom ggplot2 geom_violin
#' @importFrom ggplot2 position_dodge
#' @importFrom plotly ggplotly
#' @importFrom plotly renderPlotly
#' @importFrom data.table fread
#' @importFrom shinyjs disable
#' @importFrom shinyjs enable
#'
#' @export
panelOutputModule <- function(input, output, session,
                              anaID,
                              filesListData = reactive(NULL), active) {

  ns <- session$ns

  # Reactive values & parameters -----------------------------------------------

  result <- reactiveValues(
    #plot and panel title
    Title = "",
    Granularities = character(0),
    Losstypes = character(0),
    Variables = character(0)
  )

  # reactive values holding checkbox state
  chkbox <- list(
    chkboxgrplosstypes = reactiveVal(NULL),
    chkboxgrpvariables = reactiveVal(NULL),
    chkboxgrpgranularities = reactiveVal(NULL)
  )

  lapply(names(isolate(chkbox)), function(id) {
    observe(chkbox[[id]](input[[id]]))
  })

  #reactive triggered by the existence of the input$plottype and the changes in the data. It hoplds the selected plottype
  inputplottype <- reactive(if (active()) {
    filesListData()
    input$inputplottype
  })

  # Clean up objects------------------------------------------------------------
  #clean up panel objects when inactive
  observe(if (!active()) {
    result$Title <- ""
    result$Granularities <- character(0)
    result$Losstypes <- character(0)
    result$Variables <- character(0)
    # plotlyOutput persists to re-creating the UI
    output$outputplot <- renderPlotly(NULL)
    for (id in names(chkbox)) chkbox[[id]](NULL)
  })

  observeEvent(inputplottype(), {
    result$Title <- ""
    output$outputplot <- renderPlotly(NULL)
    if (length( plottypeslist[[inputplottype()]]$uncertaintycols) > 0) {
      show("chkboxuncertainty")
    } else {
      updateCheckboxInput(session = session, inputId = "chkboxuncertainty", value = FALSE)
      hide("chkboxuncertainty")
    }
  })

  # Enable / Disable options ---------------------------------------------------

  # > based on analysis ID -----------------------------------------------------
  #Gather the Granularities, Variables and Losstypes based on the anaID output presets
  observe(if (active()) {
    if (!is.null(filesListData() )) {
      result$Granularities <- unique(filesListData()$summary_level)
      result$Losstypes <- toupper(unique(filesListData()$perspective))
      result$Variables <- unique(filesListData()$report)
    } else {
      result$Granularities <- character(0)
      result$Losstypes <-  character(0)
      result$Variables <-  character(0)
    }
  })

  observeEvent({
    inputplottype()
    result$Losstypes
    result$Granularities
    result$Variables
  }, ignoreNULL = FALSE, {
    if (!is.null(inputplottype())) {
      .reactiveUpdateSelectGroupInput(result$Losstypes, output_options$losstypes, "chkboxgrplosstypes", inputplottype())
      .reactiveUpdateSelectGroupInput(result$Variables, output_options$variables, "chkboxgrpvariables", inputplottype())
      .reactiveUpdateSelectGroupInput(result$Granularities, output_options$granularities, "chkboxgrpgranularities", inputplottype())
    }
  })

  # > based on inputs ----------------------------------------------------------
  #GUL does not have policy
  observeEvent({
    chkbox$chkboxgrplosstypes()
    inputplottype()
  }, ignoreNULL = FALSE, {
    #if losstype = GUL then policy inactive
    if ( "GUL" %in% chkbox$chkboxgrplosstypes()) {
      Granularities <- result$Granularities[which(result$Granularities != "Policy")]
    } else {
      Granularities <- result$Granularities
    }
    .reactiveUpdateSelectGroupInput(Granularities, output_options$granularities, "chkboxgrpgranularities", inputplottype())
    .reactiveUpdateSelectGroupInput(result$Variables, output_options$variables, "chkboxgrpvariables", inputplottype())
  })

  # > button based on selection
  observeEvent({
    chkbox$chkboxgrplosstypes()
    chkbox$chkboxgrpvariables()
    chkbox$chkboxgrpgranularities()
    input$abuttondraw
  }, ignoreNULL = FALSE, {

    if (length(chkbox$chkboxgrplosstypes()) == 0 ||
        length(chkbox$chkboxgrpvariables()) == 0 ||
        length(chkbox$chkboxgrpgranularities()) == 0 ) {
      disable("abuttondraw")
    } else {
      enable("abuttondraw")
    }

  })

  # Extract dataframe to plot --------------------------------------------------
  #Logic to filter the files to plot
  #Missing logic in case either variables or granularities are not selected. For the moment not allowed
  observeEvent(input$abuttondraw, {

    # > print current selection
    logMessage(paste0("Plotting ", inputplottype(),
                      " for loss types: ", chkbox$chkboxgrplosstypes(),
                      ", variables: ", chkbox$chkboxgrpvariables(),
                      ", granularities: ",chkbox$chkboxgrpgranularities()
                      # ", aggregated to Portfolio Level: ", input$chkboxaggregate
    ))

    # > Setup ------------------------------------------------------------------
    # >> clear data
    # Content to plot
    fileData <- NULL
    # List of files to plot
    filesToPlot <- NULL
    # ggplot friendly dataframe to plot
    data <- NULL
    # DF indicating structure of the plot
    plotstrc <- data.frame("Loss" = NULL, "Variable" = NULL, "Granularity" = NULL)
    # single plot or grid
    multipleplots = FALSE

    # >> Plot parameters
    key <- plottypeslist[[inputplottype()]]$keycols
    uncertainty <- plottypeslist[[inputplottype()]]$uncertaintycols
    reference <- plottypeslist[[inputplottype()]]$referencecols
    keycols <- c(key, uncertainty, reference)
    x <- plottypeslist[[inputplottype()]]$x
    xtickslabels <- plottypeslist[[inputplottype()]]$xtickslabels
    suffix <- c("perspective", "report", "summary_level" )
    extracols <- plottypeslist[[inputplottype()]]$extracols
    xlabel <- plottypeslist[[inputplottype()]]$xlabel
    ylabel <- plottypeslist[[inputplottype()]]$ylabel
    plottype <- plottypeslist[[inputplottype()]]$plottype

    # >> sanity checks
    # something must be selected
    # only one granularity is allowed
    # we can compare either multi-variables or multi-losstypes
    l_losstypes <- length(chkbox$chkboxgrplosstypes())
    l_variables <- length(chkbox$chkboxgrpvariables())
    l_granularities <- length(chkbox$chkboxgrpgranularities())
    sanytyChecks <- FALSE
    if (l_losstypes > 1 && l_variables > 1) {
      oasisuiNotification(type = "error",
                           "Only comparisons among perspectives or reports are allowed.")
    } else {
      logMessage("Sanity checks passed")
      sanytyChecks <- TRUE
      # >> define plot structure
      plotstrc <- data.frame("perspective" = c(l_losstypes), "report" = c(l_variables), "summary_level" = c(l_granularities))
    }


    # >> define dynamic default title
    if (sanytyChecks) {
      if (input$textinputtitle != "") {
        result$Title <- input$textinputtitle
      } else {
        if (l_losstypes > 1) {
          result$Title <- paste0(chkbox$chkboxgrpvariables(), " per ", chkbox$chkboxgrpgranularities())
        } else if (l_variables > 1) {
          result$Title <- paste0(chkbox$chkboxgrplosstypes(), " per ", chkbox$chkboxgrpgranularities())
        } else {
          result$Title <- paste0(chkbox$chkboxgrpvariables(), " of ", chkbox$chkboxgrplosstypes(), " per ", chkbox$chkboxgrpgranularities())
        }
      }
    }

    # > filter out files to read -----------------------------------------------
    if (sanytyChecks) {
      if (!is.null(filesListData()) & nrow(plotstrc) > 0 ) {
        filesToPlot <- filesListData()  %>% filter(perspective %in% tolower(chkbox$chkboxgrplosstypes()),
                                                   report %in% chkbox$chkboxgrpvariables(),
                                                   summary_level %in%  chkbox$chkboxgrpgranularities())
        if (nrow(filesToPlot) != prod(plotstrc)) {
          oasisuiNotification(type = "error",
                               "The analysis did not produce the selected output. Please check the logs.")
          filesToPlot <- NULL
        }
      }
    }

    # > read files to plot -----------------------------------------------------
    if (!is.null(filesToPlot)) {
      for (i in seq(nrow(filesToPlot))) { # i<- 1
        currfileData <- .readFile(filesToPlot$files[i])
        if (nrow(currfileData) > 0) {
          #Change column names for joining by adding an extension representing the losstype the variable or the granularity to comapre
          nonkey <- names(currfileData)[ !(names(currfileData) %in% keycols)]
          gridcol <- names(currfileData)[ !(names(currfileData) %in% keycols) & !(names(currfileData) %in% extracols) & !(names(currfileData) %in% x)]
          if (any(which(plotstrc > 1))) {
            extension <- filesToPlot[i, suffix[which(plotstrc > 1)]] # losstype or Variable
          } else {
            extension <- filesToPlot[i, suffix[3]] # granularity
          }
          for (k in keycols) {
            newnamekey <- paste0(k, ".", extension)
            names(currfileData)[names(currfileData) == k] <- newnamekey
          }
          #Join data
          if (is.null(fileData)) {
            fileData <- currfileData
          } else {
            fileData <- left_join(fileData, currfileData, by = nonkey )
          }
        } else {
          fileData <- NULL
        }
      }
    }

    # Make ggplot friendly -----------------------------------------------------
    if (!is.null(fileData)) {
      data <- fileData %>% gather(key = variables, value = value, -nonkey) %>% separate(variables, into = c("variables", "keyval"), sep = "\\.") %>% spread(variables, value)
      # rename column for Y axis
      data <- data %>% rename("value" = key)
      # rename column for x axis
      data <- data %>% rename("xaxis" = x)
      # rename column for granularity. Can be null if granularity level is portfolio
      if (length(gridcol) > 0) {
        data <- data %>% rename("gridcol" = gridcol)
      }
      # rename column for uncertainty. Not all files will have it
      if (length(uncertainty) > 0) {
        data <- data %>% rename("uncertainty" = uncertainty)
      }
      # rename column for refernece. Not all files will have it
      if (length(reference) > 0) {
        data <- data %>% rename("reference" = reference)
      }
      # make multiplots if more than one losstype or variable is selected
      if ( (any(plotstrc > 1) | plottype == "violin" ) & length(gridcol) > 0 ) {
        multipleplots <- TRUE
        data <- data %>% rename("colour" = keyval)
      } else {
        multipleplots <- FALSE
        if (length(gridcol) > 0) {
          data <- data %>% rename("colour" = "gridcol")
        }  else {
          data <- data %>% rename("colour" = keyval)
        }
      }
    }

    # > draw plot --------------------------------------------------------------
    if (!is.null(data)) {
      if (plottype == "line") {
        p <- .linePlotDF(xlabel, ylabel, toupper(result$Title), data,
                         multipleplots = multipleplots)
      } else if (plottype == "bar") {
        p <- .barPlotDF (xlabel, ylabel, toupper(result$Title), data, wuncertainty = input$chkboxuncertainty, multipleplots = multipleplots, xtickslabels = xtickslabels)
      }else if (plottype == "violin") {
        p <- .violinPlotDF(xlabel, ylabel, toupper(result$Title), data,
                           multipleplots = multipleplots)
      }
      output$outputplot <- renderPlotly({ggplotly(p)})
    } else {
      oasisuiNotification(type = "error", "No data to plot.")
    }

  })

  # Helper functions -----------------------------------------------------------

  # Helper function to enable and dosable checkboxes based on condition
  .reactiveUpdateSelectGroupInput <- function(reactivelistvalues, listvalues, inputid, plotType) {
    logMessage(".reactiveUpdateSelectGroupInput called")
    # disable and untick variables that are not relevant
    if (inputid == "chkboxgrpvariables" && !is.null(plotType)) {
      relevantVariables <- plottypeslist[[plotType]][["Variables"]]
      selectable <- intersect(reactivelistvalues, relevantVariables)
    } else {
      selectable <- as.character(reactivelistvalues)
    }
    selection <- intersect(selectable, chkbox[[inputid]]())
    updateCheckboxGroupInput(session = session, inputId = inputid, selected = FALSE)
    # N.B.: JavaScript array indices start at 0
    js$disableCheckboxes(checkboxGroupInputId = ns(inputid),
                         disableIdx = which(listvalues %in% setdiff(listvalues, selectable)) - 1)
    updateCheckboxGroupInput(session = session, inputId = inputid, selected = selection)
  }

  # Helper function to read one file from DB
  .readFile <- function(fileName){
    if (!is.na(fileName)) {
      logMessage(paste0("Reading file ", fileName))
      tryCatch({
        fileData <- session$userData$data_hub$get_ana_outputs_dataset_content(id = anaID(), dataset_identifier = fileName)
      }, error = function(e) {
        oasisuiNotification(type = "error",
                             paste0("Could not read file: ", e$message, "."))
        fileData <- NULL
      })
    } else {
      oasisuiNotification(type = "error",
                           "Invalid file.")
      fileData <- NULL
    }
    return(fileData)
  }
  # > Plot helper functions ----------------------------------------------------
  #Helper functions to plot DF
  #Expected DF with columns:
  # xaxis : column for aes x
  # value : column for aes y
  # colour : column for the aes col
  # flag multipleplots generates grid over col gridcol
  .basicplot <- function(xlabel, ylabel, titleToUse, data){
    p <- ggplot(data, aes(x = xaxis, y = value, col = as.factor(colour))) +
      labs(title = titleToUse, x = xlabel, y = ylabel) +
      theme(
        plot.title = element_text(color = "grey45", size = 14, face = "bold.italic", hjust = 0.5),
        text = element_text(size = 12),
        panel.background = element_blank(),
        axis.line.x = element_line(color = "grey45", size = 0.5),
        axis.line.y = element_line(color = "grey45", size = 0.5),
        legend.title =  element_blank(),
        legend.position = "top"
      )
    p
  }

  # add a horizontal line
  .addRefLine <- function(p, reference){
    if (!is.null(reference)) {
      p <- p + geom_hline(yintercept = reference)
    }
    p
  }

  # add facets
  .multiplot <- function(p, multipleplots = FALSE){
    if (multipleplots) {
      p <- p + facet_wrap(.~ gridcol)
    }
    p
  }

  # Line plot
  .linePlotDF <- function(xlabel, ylabel, titleToUse, data, multipleplots = FALSE){
    p <- .basicplot(xlabel, ylabel, titleToUse, data)
    p <- p +
      geom_line(size = 1) +
      geom_point(size = 2)
    p <- .multiplot(p, multipleplots)
    p
  }

  # Bar Plot
  .barPlotDF <- function(xlabel, ylabel, titleToUse, data, wuncertainty = FALSE, multipleplots = FALSE, xtickslabels = NULL ){
    p <- .basicplot(xlabel, ylabel, titleToUse, data)
    p <- p +
      geom_bar(position = "dodge", stat = "identity", aes(fill = as.factor(colour))) +
      scale_x_continuous(breaks = seq(max(data$xaxis)), labels = xtickslabels)
    if (wuncertainty){
      p <- p +
        geom_errorbar(aes(ymin = value - uncertainty, ymax = value + uncertainty),
                      size = .3,
                      width = .2,                    # Width of the error bars
                      position = position_dodge(.9))
      # if ("reference" %in% names(data)) {
      #   p <- .addRefLine(p, unique(data$reference))
      # }
    }
    p <- .multiplot(p,multipleplots)
    p
  }

  # Violin Plot
  .violinPlotDF <- function(xlabel, ylabel, titleToUse, data, multipleplots = FALSE){
    p <- .basicplot(xlabel, ylabel, titleToUse, data)
    p <- p +
      geom_violin(aes(fill = colour, alpha = 0.2), show.legend = FALSE)
    p <- .multiplot(p,multipleplots)
    p
  }

  # Module Output --------------------------------------------------------------
  reactive(result$Title)
}
