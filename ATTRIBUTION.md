# Attribution and source provenance

The combined elara-core package is distributed under the GNU Affero General
Public License version 3.0; see [LICENSE](LICENSE). Individual upstream
contributions retain the notices and licenses described below. Attribution
alone does not replace the conditions of those licenses. In particular, the
AGPL has conditions for conveying modified works and for certain network uses.

## OpenCiclo

Source: <https://github.com/OpenCiclo/OpenCiclo-web>, commit
`28f14c34603ba2a846d010351ccd38c78c73e92d`. License: Apache-2.0. Copyright
2026 Emma Flora Harbison and Luis Rey Sánchez. The shrinkage-median estimate,
mixed scale, discrete Laplace distribution, and released mcPHASES aggregate
prior are adapted in `openciclo_engine.dart`. The released artifact uses
population median 30.5, MAD 3.0, mean 29.50769230769231, shrinkage strength
2.0, no last-cycle blend, and the Laplace family. The original license and
notice are in [LICENSES/Apache-2.0.txt](LICENSES/Apache-2.0.txt) and
[LICENSES/OpenCiclo-NOTICE.txt](LICENSES/OpenCiclo-NOTICE.txt). The original
notice's trademark restrictions still apply.

The originally supplied URL `https://github.com/lmcinnes/openciclo` was not
accessible when inspected; the repository above contains the referenced
`openciclo/artifacts/released_model.json` and source implementation.

## Flowlytics

Source: <https://github.com/harshit2k4/flowlytics>, commit
`c7152503fa6ee88b7f543931de0f928794b2b691`. License: AGPL-3.0. Flowlytics
contributors' enhanced prediction and navigator rules are adapted in
`flowlytics_engine.dart`: the six-cycle recency weights, deviation and
confidence thresholds, and dated symptom adjustments. ELARA deliberately
requires an explicit observation date and explicit confirmation of a *new*
period start; spotting alone is not treated as an observed period start by
fusion. The applicable AGPL text is [LICENSE](LICENSE).

The originally supplied URL `https://github.com/Flowlytics/flowlytics` was
not accessible when inspected; the repository above contains the described
prediction and navigator engines.

## Vani

Source: <https://github.com/nkrider7/vani>, commit
`e5f69dc20b1ffd2c641576534b722984a0a71e9f`. License: MIT as stated in the
upstream README; the inspected repository does not contain a standalone
license file or a package license field. Its calendar mean, weighted mean,
standard-deviation confidence and irregularity note were inspected but not
ported because they do not add a distinct forecasting method. The WMA code
also reverses its weights, favoring older intervals contrary to its comment.
No Vani source is copied into the library.

## drip and sympto

App source: <https://gitlab.com/bloodyhealth/drip>, commit
`adf68f6163bf8574d0111fd98675e562bc12cbbe`. License: GPL-3.0-or-later. The
app's mucus quality conversion and observation conventions were adapted.

Core source: <https://gitlab.com/bloodyhealth/sympto>, version 3.0.2, commit
`cd7b99fd4c70d69d438cdedac464951bbb599116`. License: AGPL-3.0-or-later;
contributors named upstream include Julia Friesel, Marie Kochsiek and Tina
Baumann. Its temperature shift, exceptions, mucus peak, combined phase,
five-day and minus-eight rules were adapted in `drip_engine.dart`. The
`test/fixtures/sympto_parity.json` test data and expected results are derived
from its test fixtures. See [LICENSES/GPL-3.0-or-later.txt](LICENSES/GPL-3.0-or-later.txt)
and [LICENSES/AGPL-3.0-or-later.txt](LICENSES/AGPL-3.0-or-later.txt).

Neither project supplies ELARA's optional period bridge: treating the first
higher-temperature day as an ovulation proxy, adding 14 days, and assigning
a confidence score and uncertainty window are unvalidated ELARA choices.
