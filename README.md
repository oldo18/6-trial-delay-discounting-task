# 6-trial delay discounting task

A browser implementation of the 6-trial adjusting delay discounting task (Koffarnus, Rzeszutek & Kaplan, 2021), a variant of the 5-trial "minute discounting task" (Koffarnus & Bickel, 2014). It estimates a participant's discount rate *k* from six binary choices in about a minute.

The task was used for data collection in my master's thesis at the Faculty of Social Studies, Masaryk University. The participant-facing text is in Czech, exactly as respondents saw it.

## Procedure

Each trial offers half of a fixed amount now or the full amount after a delay (500 € now vs. 1000 € later by default). Delays form a ladder of 63 nodes from 5 seconds to 65 years. The first trial is at node 32 (1 day); an immediate choice shortens the next delay and a delayed choice lengthens it, with steps of 16, 8, 4, 2 and 1 nodes. The final node and the last choice determine *k* according to Table 3 of Koffarnus et al. (2021).

If the first five choices are all immediate or all delayed, the sixth trial is an attention check (0 now vs. the full amount in 5 seconds, or the full amount now vs. the full amount in 65 years). Passing it yields the extreme *k* of the scale, failing it yields `null`.

Option order is randomized on every trial and response times are recorded for each choice.

## Configuration

Everything is set at the top of the script in `index.html`. None of these settings affect the procedure or the scoring.

- `CONFIG.AMOUNT_EUR`: the larger, later amount; the sooner amount is always half.
- `CONFIG.EUR_TO_CZK`: exchange rate used to show amounts in CZK (24.2 in the original study, update as needed). Participants can switch between CZK and EUR; `DEFAULT_CURRENCY` sets the initial one.
- `T` and `LABELS`: all participant-facing text and the 63 delay labels. Translating these two objects is enough to run the task in another language.
- `CONFIG.MIN_PLAUSIBLE_RT_MS`: responses faster than this are flagged (300 ms).
- `CONFIG.SUBMIT_URL`: endpoint that receives the result as a JSON `POST`. If empty, the participant is offered a JSON download instead.
- A `?pid=` URL parameter is stored as the participant ID, so the task can be linked to another questionnaire.

## Output

| Field | Description |
|---|---|
| `dd_k` | Discount rate *k* (per day); `null` if the attention check was failed |
| `dd_log10_k` | log10 of *k* |
| `dd_ed50_days` | ED50 = 1/*k* in days (Yoon & Higgins, 2008) |
| `dd_attention_triggered`, `dd_attention_type`, `dd_attention_passed` | Attention check shown, type (`A` all immediate, `B` all delayed), passed |
| `dd_min_rt_ms`, `dd_flag_too_fast` | Fastest response, any response below the threshold |
| `dd_t1_*` … `dd_t6_*` | Per trial: `kind`, `node`, `delay_label`, `choice` (`imm`/`del`), `rt_ms` |

Plus `participant_id`, `study_id`, `currency`, `amount_eur`, `started_at` and `finished_at`.

## Storage

The task is a single static file and runs on any hosting. The repository includes the setup used in the original study: a Vercel function (`api/submit.js`) that writes results to Supabase. To use it, run `supabase/schema.sql` in your Supabase project and set `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` as environment variables in Vercel. Results can be exported from the `ddt_export` view. With any other backend, point `SUBMIT_URL` to it and remove `api/`, `supabase/` and `vercel.json`.

## References

Koffarnus, M. N., & Bickel, W. K. (2014). A 5-trial adjusting delay discounting task: Accurate discount rates in less than one minute. *Experimental and Clinical Psychopharmacology, 22*(3), 222–228. https://doi.org/10.1037/a0035973

Koffarnus, M. N., Rzeszutek, M. J., & Kaplan, B. A. (2021). *Additional discounting rates in less than one minute: Task variants for probability and a wider range of delays* [Unpublished manuscript]. Department of Family and Community Medicine, University of Kentucky.

Yoon, J. H., & Higgins, S. T. (2008). Turning k on its head: Comments on use of an ED50 in delay discounting research. *Drug and Alcohol Dependence, 95*(1–2), 169–172. https://doi.org/10.1016/j.drugalcdep.2007.12.011

## License

Public domain (see `LICENSE`). No attribution to this repository is needed; if you use the task in research, please cite the original authors of the procedure.
