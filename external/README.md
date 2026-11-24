# External source packages

The bundled directories contain source snapshots at specific commits. Each package
includes its upstream licenses, documentation, examples and tracked test data. Build
and install the packages you need on your machine. The distribution excludes local
builds, installed copies and nested `.git` directories. The snapshots are regular
directories. The [source manifest](sources.json) records the upstream repositories
and full commit IDs.

| Package | Purpose and entry point | Build and installation |
| --- | --- | --- |
| DlogBasis-refine | Bounded search for integral candidates with `DlogBasis.wl` | Load the Wolfram source directly. Candidate search requires FiniteFlow and Singular. [README](DlogBasis-refine/README.md) |
| CANONICA | Rational differential-equation transformations and lower-sector tails with `src/CANONICA.m` | Load the Wolfram source directly. [README](CANONICA/README) |
| Libra | Differential-equation transformations and repair of the matrix structure with `Source/Libra.m` | [README](Libra/Readme.md) and [INSTALL](Libra/INSTALL) |
| Fermatica | Wolfram interface to Fermat in `source/Fermatica.wl` | Install Fermat and set `FERMATPATH`. [README](Fermatica/README.md) |
| INITIAL | Bounded core construction from a trusted seed with `INITIAL.m`, and the official fixed ladder reference calculation | Install FiniteFlow first. [README](INITIAL/README.md) |
| FiniteFlow | Finite-field arithmetic with `mathlink/FiniteFlow.m` | Use CMake to build the native library for your Wolfram installation. [README](FiniteFlow/README.md) |
| Kira | IBP reduction with the installed `kira` executable | The snapshot is version 3.1. Parts of its README describe the 2.x series. [README](Kira/README.rst) and [Meson build file](Kira/meson.build) |
| Singular | Module solver for combining DlogBasis-refine candidates, using the installed `Singular` executable | The snapshot is `Release-4-2-1p2`. Follow the upstream source installation guide in the [README](Singular/README.md). |

DlogBasis-refine uses Singular to solve the module equations during candidate
search, including when `residual_backend` uses its default value `Current`.

CANON maintains the DlogBasis-refine variant. The origin in the manifest identifies
its historical upstream. Publication of this variant's commit there is unconfirmed.
The manifest records the distribution edits to the skill's path instructions and the
study's revision tracking. The workflow uses `DlogBasisSearch` in the `DlogBasis`
context, which supersedes the earlier LS archive.

The Fermat author supplies the GPL source on request. Fermat source and binaries are
distributed separately from CANON. [Obtaining Fermat](Fermat/README.md)

## Build dependencies and local configuration

Follow the instructions for the packages you select when installing build tools,
Mathematica, Python, Git and libraries such as GMP, MPFR, FLINT, CLN, GiNaC, zlib,
yaml-cpp, FireFly, MPI and jemalloc. The distribution includes only the dependencies
already tracked by upstream. These include factory, libpolys, omalloc and gfanlib in
Singular, and sqlite3 in Kira. Kira's `.wrap` files describe additional
dependencies. To restrict a Kira build to installed libraries, pass
`--wrap-mode=nofallback` to Meson.

Supply installation paths through your local configuration and task parameters.
Machine-specific configuration is kept outside the repository.

| Setting | Purpose |
| --- | --- |
| `PATH` | Finds installed commands such as `WolframKernel`, `wolframscript`, `kira` and `Singular`. |
| `CANON_WOLFRAM_KERNEL` | Selects the Wolfram kernel for Python tests. The tests otherwise search `PATH`. |
| `FERMATPATH` | Full path to the Fermat executable used by Fermatica or Kira. A Wolfram session can also set ``Fermatica`$FermatCMD``. |
| `method_options.package_entry` | Main package file for the selected method. Methods that support a standard Wolfram installation can also use `$Path`. |
| `method_options.finite_flow_package_file` | Path to the FiniteFlow `.m` file. The native library uses the local `$LibraryPath`. |
| `method_options.singular_executable` | Singular command or executable path for DlogBasis-refine. The default is `Singular`. |
| `executable` and `options` in a Kira request | Reducer command and explicit resource settings such as `--parallel=1`. |

Relative paths for artifacts and packages resolve from the JSON file that declares
them. Resources in a family specification resolve from that specification. Expand
environment variables and `~` before writing paths into JSON strings. Generated
artifacts record the absolute paths and hashes from their run. When moving research
state, preserve the dependencies and bind the new runtime paths explicitly.

## Standalone INITIAL configuration

The [official ladder reference workflow](../methods/initial/reference/README.md)
uses the following paths and component identifiers in `method_options`. Set the
native library filename for your platform. Paths in this example are relative to the
input JSON file.

```json
{
  "package_entry": "../external/INITIAL/INITIAL.m",
  "finite_flow_package_file": "../external/FiniteFlow/mathlink/FiniteFlow.m",
  "finite_flow_library": "../installed/lib/fflowmlink.so",
  "reference_directory": "../external/INITIAL/examples/massless_3L4P",
  "initial_identity": "INITIAL 2.1; 63d8f813ac415f82f7ef945ee7e3f78a242fae49",
  "finiteflow_identity": "FiniteFlow; 278344c169010b74e791af8c5604c8cb9cd8df11",
  "threads": 1
}
```

Set `CANON_TEST_INITIAL_CONFIG` to a JSON file containing the four component paths
and optional `threads` to run the tests against an installed INITIAL. Paths in that
file resolve from its directory. The independent checker reads `package_entry`,
`finite_flow_package_file` and `reference_directory` and runs without loading the
native library. The reference result applies to the recorded component versions. The
caller chooses the platform, installation paths and thread count.

For the [INITIAL seed-based core method](../methods/initial/SKILL.md), supply
`package_entry`, `finite_flow_package_file`, `finite_flow_library` and the declared
component identities. Also supply explicit `threads`, `timeout_seconds`,
`max_iterations`, `max_degree` and `max_primes`, along with the seed rows,
normalization evidence, alphabet and derivative assignments. Set
`step="SEARCH_CORE"` in the request to `methods/initial/run.wls`. The method emits
`core_candidates` for `CHECK_CORE`. Verify tool availability on the target machine.
The scope of a validated run applies to the configuration used on that machine.

Other tests against installed providers use `CANON_TEST_CANONICA_ENTRY`,
`CANON_TEST_LIBRA_ENTRY`, `CANON_TEST_DLOGBASIS_REFINE_ENTRY` and
`CANON_TEST_FINITEFLOW_ENTRY`. Set `CANON_TEST_DLOGBASIS_REVISION` to declare the
DlogBasis revision. Tests explicitly skip unconfigured providers. A DlogBasis
regression can set `CANON_TEST_SINGULAR_ENTRY` to the absolute executable path to
select Singular independently of the test process's `PATH`.

Historical notebook output, generator comments, platform help settings and examples
can contain their authors' paths. The older Singular OpenMath and Python demos and
their sample Makefiles also use upstream paths. Configure these when running those
demos locally. The snapshots retain upstream resources such as Singular's
`surfex.jar` and Kira's compressed test inputs. CANON installation uses the caller's
paths and adds no locally compiled files to the snapshots.
