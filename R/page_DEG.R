DEG_ui <- function(id, all_exp, browser_options, label = "DEG") {
  ns <- NS(id)
  genomes <- unique(all_exp$organism)
  experiments <- all_exp$name
  tabPanel(
    title = "Differential expression", icon = icon("layer-group"),
    sidebarLayout(
      jqui_resizable(jqui_draggable(sidebarPanel(
        tabsetPanel(
          tabPanel("Differential expression",
                   organism_input_select(c("ALL", genomes), ns),
                   experiment_input_select(experiments, ns, browser_options),
                   library_input_select(ns),
                   condition_input_select(ns),
                   helper_button_redirect_call()
          ),
          tabPanel("Settings",
                   checkboxInput(ns("draw_unnreg"), label = "Draw unregulated", value = FALSE),
                   checkboxInput(ns("other_tx"), label = "Full annotation", value = FALSE),
                   sliderInput(ns("pval"), "P-value", min = 0, max = 1,
                               value = 0.05, step = 0.01),
                   export_format_of_plot(ns)
          ),
        ),
        actionButton(ns("go"), "Plot", icon = icon("rocket")),
      ))),
      mainPanel(
        jqui_resizable(plotlyOutput(outputId = ns("c"), height = "500px")) %>% shinycssloaders::withSpinner(color="#0dc5c1"),
        uiOutput(ns("variableUi")
      ))
    )
  )
}


DEG_server <- function(id, all_experiments, env, df, experiments, libs,
                       org, rv) {
  moduleServer(
    id,
    function(input, output, session, all_exp = all_experiments) {

      # Update main side panels
      uses_gene <- FALSE
      study_and_gene_observers(input, output, session)
      cond <- reactive(df()$condition)
      observeEvent(cond(), condition_update_select(cond))

      # Main plot, this code is only run if 'plot' is pressed
      controls <- eventReactive(input$go,
                                        click_plot_DEG_main_controller(input, df))
      DESeq2_model <- reactive(DEG_model(controls()$dff)) %>%
        bindCache(controls()$hash_string_pre)

      analysis_dt <- reactive(DEG_model_results(DESeq2_model(),
            controls()$target.contrast, pairs = controls()$pairs,
            controls()$pval)) %>%
        bindCache(controls()$hash_string_full)
      output$c <- renderPlotly(DEG_plot(analysis_dt(),
                draw_non_regulated = controls()$draw_unregulated)) %>%
        bindCache(controls()$hash_string_full)
      # output$c <- renderPlotly(ggplotly(ggplot(aes(x= 1:length(analysis_dt()), y = 1:length(analysis_dt()))) + geom_point()))
      return(rv)
    }
  )
}
