#' Create RiboCrypt app
#' @param validate.experiments logical, default TRUE, set to FALSE
#' to allow starting the app with malformed experiments, be careful
#' will crash if you try to load that experiment!
#' @param options list of arguments, default
#'  \code{list("launch.browser" = ifelse(interactive(), TRUE, FALSE))}
#' @param all_exp a data.table, default:
#' \code{list.experiments(validate = validate.experiments)}. Which experiments
#' do you want to allow your app to see, default is all in your system config
#' path.
#' @param browser_options named character vector of browser specific arguments:\cr
#' - default_experiment : Which experiment to select, default: first one\cr
#' - default_gene : Which genes to select, default: first one\cr
#' - default_libs : Which libraries to select: first one, else a single string,
#' where libs are seperated by "|", like "RFP_WT_r1|RFP_WT_r2".\cr
#' - default_kmer : K-mer windowing size, default: 1\cr
#' - default_frame_type : Ribo-seq line type, default: "lines"\cr
#' - plot_on_start : Plot when starting, default: "FALSE"\cr
#' @param init_tab_focus character, default "browser". Which tab to open on
#' init.
#' @import shiny bslib ORFik NGLVieweR ggplot2
#' @importFrom shinycssloaders withSpinner
#' @importFrom markdown mark_html
#' @importFrom shinyjqui jqui_resizable jqui_draggable
#' @importFrom knitr knit
#' @importFrom stringr str_sub
#' @importFrom httr GET write_disk
#' @return RiboCrypt shiny app
#' @export
#' @examples
#' ## Default run
#' # RiboCrypt_app()
#' ## Plot on start
#' # RiboCrypt_app(browser_options = c(plot_on_start = "TRUE"))
#' ## Init with an experiment and gene (you must of course have the experiment)
#'
#' #RiboCrypt_app(validate.experiments = FALSE,
#' #       browser_options = c(plot_on_start = "TRUE",
#' #                           default_experiment = "human_all_merged_l50",
#' #                           default_gene = "ATF4-ENSG00000128272"))
RiboCrypt_app <- function(
    validate.experiments = TRUE,
    options = list("launch.browser" = ifelse(interactive(), TRUE, FALSE)),
    all_exp = list.experiments(validate = validate.experiments),
    browser_options = c(), init_tab_focus = "browser") {
  time_before <- Sys.time()

  stopifnot(is(all_exp, "data.table"))
  stopifnot(!is.null(all_exp$name))
  stopifnot(nrow(all_exp) > 0)
  # Set environments
  with_readlengths_env <- new.env()
  without_readlengths_env <- new.env()
  #with_cigar_env <- new.env() # Not used for now
  # Add resource directories
  addResourcePath(prefix = "images",
                  directoryPath = system.file("images", package = "RiboCrypt"))
  addResourcePath(prefix = "rmd",
                  directoryPath = system.file("rmd", package = "RiboCrypt"))
  # Setup variables
  if (!isTruthy(browser_options["default_experiment"])) {
    browser_options["default_experiment"] <- all_exp$name[1]
  }
  if (is.na(browser_options["plot_on_start"])) {
    browser_options["plot_on_start"] <- FALSE
  }

  if (!isTruthy(browser_options["allow_non_bw"])) {
    browser_options["allow_non_bw"] <- FALSE
  }
  exp_init <- read.experiment(browser_options["default_experiment"],
                              validate = FALSE)
  names_init <- get_gene_name_categories(exp_init)
  if (!isTruthy(browser_options["default_gene"])) {
    if (!isTruthy(browser_options["default_gene"])) {
      browser_options["default_gene"] <- names_init$label[1]
    }
    stopifnot(browser_options["default_gene"] %in% names_init$label)
  }
  if (!isTruthy(browser_options["default_kmer"])) {
    browser_options["default_kmer"] <- 1
  } else {
    stopifnot(!is.na(as.numeric(browser_options["default_kmer"])))
  }
  if (!isTruthy(browser_options["default_frame_type"])) {
    browser_options["default_frame_type"] <- "lines"
  } else {
    stopifnot(is.character(browser_options["default_frame_type"]))
  }
  libs <- bamVarName(exp_init)
  if (!isTruthy(browser_options["default_libs"])) {
    browser_options["default_libs"] <- libs[1]
  } else {
    default_libs <- unlist(strsplit(browser_options["default_libs"], "\\|"))
    if (!all(default_libs %in% libs))
      stop("You defined default_libs, but some of those are not valid names,",
      " in selected experiment!")
  }
  # User interface
  ui <- tagList(
    rc_header_image(),
    navbarPage(
      lang = "en",
      windowTitle = "RiboCrypt",
      title = rc_title(),
      theme = rc_theme(),
      selected = init_tab_focus,
      browser_ui("browser", all_exp, browser_options, names_init, libs),
      analysis_ui("analysis", all_exp, browser_options, libs),
      metadata_ui("metadata", all_exp),
      tutorial_ui()
    )
  )

  server <- function(input, output, session) {
    cds <- NULL
    org_and_study_changed_checker(input, output, session)

    rv <- browser_server("browser", all_exp, without_readlengths_env, df,
                         experiments, tx, cds, libs, org, gene_name_list, rv,
                         browser_options)
    rv <- analysis_server("analysis", all_exp, without_readlengths_env,
            with_readlengths_env, df, df_with, experiments, tx, cds, libs, org,
            gene_name_list, rv)
    metadata_server("metadata", all_exp)
    cat("Server: "); print(round(Sys.time() - time_before, 2))
  }
  cat("Init: "); print(round(Sys.time() - time_before, 2))
  shinyApp(ui, server, options = options)
}

RiboCrypt_app_modular <- RiboCrypt_app


rc_header_image <- function() {
  tags$head(
    tags$link(rel = "icon",
              href = file.path("images", "favicon.png"),
              type = "image/x-icon"))
}

rc_theme <- function() {
  bslib::bs_theme(
    version = 5,
    primary = "#6dbaff", secondary = "#ff7e7e",
    success = "#c0ffa4", font_scale = 1.2, bootswatch = "zephyr")
}

rc_title <- function() {
  withTags(
    a(img(src = file.path("images", "logo_traces_update.png"),
          alt = "RiboCrypt",
          height = 60)))
}

