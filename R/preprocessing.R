
calc_ins_age <- function(birth, now) {
  birth6 <- add_mon(birth, 6L)
  bottom <- as.Date(ISOdate(year(now), month(birth6), day(birth6)))
  ifelse(now < bottom, year(now)-year(birth)-1, year(now)-year(birth))
}

set_age_band <- function(df, age_var, interval, right = FALSE) {
  age_var <- match_cols(df, vapply(substitute(age_var), deparse, "character"))
  age <- df[[age_var]]
  mn <- floor(min(age) / interval) * interval
  mx <- ceiling(max(age) / interval) * interval
  if (max(age) == mx) mx <- ceiling(max(age) / interval + 1) * interval
  age_band <- cut(age, breaks = seq(mn, mx, interval), right = right)
  # levels
  l <- levels(age_band)
  r <- gregexpr("[0-9]+", l, perl = TRUE)
  m <- regmatches(l, r)
  s <- as.integer(sapply(m, function(x) x[1L]))
  e <- as.integer(sapply(m, function(x) x[2L]))-1
  g <- sprintf("%d-%d", s, e)
  levels(age_band) <- g
  set(df, j = "age_band", value = age_band)
  setcolafter_(df, "age_band", age_var)
}

split_date <- function(df, from_var, to_var, udate, all = TRUE, verbose = TRUE) {
  from_var <- deparse(substitute(from_var))
  to_var <- deparse(substitute(to_var))
  for (i in seq_along(udate)) {
    tmp_e <- df[!(df[[from_var]] < udate[i] & df[[to_var]] >= udate[i])]
    tmp_a <- df[ (df[[from_var]] < udate[i] & df[[to_var]] >= udate[i])]
    tmp_b <- copy(tmp_a)
    set(tmp_a, j = to_var, value = udate[i]-1)
    set(tmp_b, j = from_var, value = udate[i])
    if (all) {
      df <- rbind(tmp_e, tmp_a, tmp_b)
    } else {
      df <- rbind(tmp_a, tmp_b)
    }
    if (verbose)
      cat(sprintf("%s is applied\n", as.Date(udate[i])))
  }
  if (verbose)
    cat("Please check hospitalization days or claim year, \nyou may have to re-calculate!\n")
  setorderv(df, names(df))
  return(df)
}

split_date_ <- function(df, from_var, to_var, udate, all = TRUE, verbose = TRUE) {
  for (i in seq_along(udate)) {
    tmp_e <- df[!(df[[from_var]] < udate[i] & df[[to_var]] >= udate[i])]
    tmp_a <- df[ (df[[from_var]] < udate[i] & df[[to_var]] >= udate[i])]
    tmp_b <- copy(tmp_a)
    set(tmp_a, j = to_var, value = udate[i]-1)
    set(tmp_b, j = from_var, value = udate[i])
    if (all) {
      df <- rbind(tmp_e, tmp_a, tmp_b)
    } else {
      df <- rbind(tmp_a, tmp_b)
    }
    if (verbose)
      cat(sprintf("%s is applied\n", as.Date(udate[i])))
  }
  if (verbose)
    cat("Please check hospitalization days or claim year, \nyou may have to re-calculate!\n")
  setorderv(df, names(df))
  return(df)
}

subset_time <- function(df, from_var, to_var, udate, start, end) {
  from_var <- match_cols(df, vapply(substitute(from_var), deparse, "character"))
  to_var   <- match_cols(df, vapply(substitute(to_var)  , deparse, "character"))
  fdate <- add_mon(udate, start)
  tdate <- add_mon(udate, end)
  z <- split_date_(df, from_var, to_var, c(fdate, tdate), verbose = FALSE)
  z[edate >= fdate & sdate < tdate]
}

subset_time_ <- function(df, from_var, to_var, udate, start, end) {
  fdate <- add_mon(udate, start)
  tdate <- add_mon(udate, end)
  z <- split_date_(df, from_var, to_var, c(fdate, tdate), verbose = FALSE)
  z[edate >= fdate & sdate < tdate]
}

merge_overlapping_date_range <- function(df, id_var, merge_var, from_var, to_var, interval = 0) {
  id_var    <- match_cols(df, vapply(substitute(id_var)   , deparse, "character"))
  merge_var <- match_cols(df, vapply(substitute(merge_var), deparse, "character"))
  from_var  <- match_cols(df, vapply(substitute(from_var) , deparse, "character"))
  to_var    <- match_cols(df, vapply(substitute(to_var)   , deparse, "character"))
  vars <- c(id_var, merge_var, from_var, to_var)
  tmp <- df[, ..vars]
  setnames(tmp, c(id_var, merge_var, "from", "to"))
  setorderv(tmp, c(id_var, "from", "to"))
  set(tmp, j = "sub_stay", value = 0)
  ind <- .Call(vuw_index_overlapping_date_range, tmp[, ..id_var],
               as_integer(tmp$from),
               as_integer(tmp$to),
               as_integer(interval))
  set(tmp, j = "loc", value = ind$loc)
  set(tmp, j = "sub", value = ind$sub)
  group <- c(id_var, "loc")
  m <- tmp[, lapply(.SD, glue_code), keyby = group, .SDcols = merge_var]
  s <- tmp[, .(from = min(from), to = max(to), sub_stay = sum(sub_stay) + sum(sub)),
           keyby = group]
  z <- m[s, on = group]
  set(z, j = "loc", value = NULL)
  set(z, j = "stay", value = as.nu(z$to - z$from + 1 - z$sub_stay))
  set(z, j = "sub_stay", value = NULL)
  setnames(z, c(vars, "stay"))
  return(z)
}

#' count stay
#'
#' This function count unique length of stay between `from_var` to `to_var`.
#' @param df data.frame, data.table
#' @param id_var id variables
#' @param from_var start date
#' @param to_var end date
#' @examples
#' @export
count_stay <- function(df, id_var, from_var, to_var) {
  id_var   <- match_cols(df, vapply(substitute(id_var)  , deparse, "character"))
  from_var <- match_cols(df, vapply(substitute(from_var), deparse, "character"))
  to_var   <- match_cols(df, vapply(substitute(to_var)  , deparse, "character"))
  if (!is.data.table(df))
    df <- as.data.table(df)
  setorderv(df, c(id_var, from_var, to_var))
  id <- df[, ..id_var]
  from <- as.integer(df[[from_var]])
  to <- as.integer(df[[to_var]])
  if (any(to - from < 0))
    stop("Some `from_var` are greater than `to_var`.")
  stay <- .Call(`vuw_count_stay`, id, from, to)
  z <- cbind(unique(id), stay = stay)
  return(z)
}

modify_stay <- function(df, id_var, from_var, to_var, limit, waiting) {
  id_var   <- match_cols(df, vapply(substitute(id_var)  , deparse, "character"))
  from_var <- match_cols(df, vapply(substitute(from_var), deparse, "character"))
  to_var   <- match_cols(df, vapply(substitute(to_var)  , deparse, "character"))
  trvs <- traverse(df[[from_var]], df[[to_var]])
  diff <- c(diff(trvs), 1)
  id_trv <- rep(df[[id_var]], each = 2L)
  pt_stt <- c(1, change_point(id_trv))
  pt_end <- change_point(id_trv) - 1
  diff[pt_end] <- 1
  adjs <- rep(c(1, -1), times = length(diff)/2)
  diff <- diff + adjs
  bins <- rep(c(1, 0), times = length(diff)/2)
  stay <- rep(bins, diff)
  df_len <- df[, .(sdate = min(get(from_var)), edate = max(get(to_var)),
                   len = as.numeric(max(get(to_var)) - min(get(from_var)) + 1L)),
               .(id = get(id_var))]
  stay_mod <- .Call(vuw_modify_stay_in_the_interval, stay, df_len$len, limit, waiting)
  pd <- num2date(with(df_len, expand_dates(sdate, edate)))
  id_len <- with(df_len, rep(id, times = len))
  z <- data.table(id = id_len, sdate = pd, stay, stay_mod)
  z <- z[!(stay == 0 & stay_mod == 0)]
  z <- z[, .(sdate = min(sdate), stay = sum(stay), stay_mod = sum(stay_mod)),
         .(id = id, period = bmonth(sdate))]
  set(z, j = "edate", value = num2date(
    ifelse(z$stay_mod > 0, z$sdate + z$stay_mod - 1L, z$sdate)
  ))
  setcolafter(z, edate, sdate)
  return(z)
}

# kcd code functions ------------------------------------------------------

pste_code <- function(x, collapse = "|") paste0(x, collapse = collapse)
glue_code <- function(x, collapse = "|") paste0(unique(x[!is.na(x)]), collapse = collapse)
sort_code <- function(x, collapse = "|") paste0(sort(unique(x[!is.na(x)])), collapse = collapse)
splt_code <- function(x, split = "\\|") {z <- strsplit(x, split = split)[[1L]]; z[!z %in% c(NA, "NA", "")]}
srch_code <- function(x) glue_code(paste0(x, "$"))
melt_code <- function(x) srch_code(splt_code(pste_code(x)))
excl_code <- function(x) paste0('^((?!', x, ').)*$')
remv_code <- function(code, x) gsub(code, "", x)
pull_code <- function(code, x) {
  r <- regexpr(code, x, perl = TRUE)
  z <- rep(NA, length(x))
  z[r != -1] <- regmatches(x, r)
  return(z)
}

set_kcd_name <- function(df, col, dots = TRUE, lang = c("ko", "en")) {
  copybook <- copy(kcd_book)
  if (dots) rm_dots(copybook, kcd)
  col <- match_cols(df, vapply(substitute(col), deparse, "character"))
  setnames(copybook, "kcd", col)
  new_col <- paste0(col, "_", lang[[1L]])
  if (lang[[1L]] == "ko") {
    df[copybook, on = col, (new_col) := i.ko]
  } else {
    df[copybook, on = col, (new_col) := i.en]
  }
}