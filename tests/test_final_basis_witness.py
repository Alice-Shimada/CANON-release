"""Exact final gates with the mandatory basis as an inverse witness."""
import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from test_workflow_boundaries import WL, wl, sealed

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = os.environ.get('CANON_WOLFRAMSCRIPT') or shutil.which('wolframscript')


def fixture(t, u, matrices, variables=('x',), alphabet=('x', '1-x')):
    source = [WL('j[1]'), WL('j[2]')]
    variables = list(map(WL, variables))
    sector = {'id': 1, 'propagator_count': 1}
    accepted = dict(schema='canon-neu/accepted-prefix/v1', family_id='inverse-witness',
        source_basis=source, basis=WL('('+u+').'+wl(source)),
        transformation=WL(t), variables=variables, regulator=WL('eps'),
        alphabet=list(map(WL, alphabet)), matrices=WL(matrices),
        sector_trace=[sector], candidate_trace=[{'sector': sector, 'candidate_id': 'fixture'}],
        convention='old_source_basis = transformation . accepted_basis')
    raw_matrices = WL('With[{t='+t+',u='+u+',b='+matrices+'},MapThread['
        'Map[Together,(D[t,#1]+t.#2).u,{2}]&,{'+wl(variables)+',b}]]')
    return dict(prepared_family=dict(family_ref='inverse-witness', basis_ref='raw',
                    variables=variables, regulator=WL('eps')),
        master_basis=dict(family_ref='inverse-witness', basis_ref='raw', masters=source),
        sector_manifest={'sectors': [sector]},
        ordered_master_de=dict(schema='canon-neu/ordered-master-de/v1', family_id='inverse-witness',
            basis_id='raw', basis=source, variables=variables, regulator=WL('eps'), matrices=raw_matrices),
        accepted_prefix=accepted)


@unittest.skipUnless(RUNTIME, 'configure CANON_WOLFRAMSCRIPT')
class FinalBasisWitnessTests(unittest.TestCase):
    def test_explicit_backend_keeps_provenance_and_mandatory_basis_gate(self):
        # Contract fixture only: exact WL arithmetic stands in for Fermatica;
        # this test never launches Fermat or claims native Fermat validation.
        objects = fixture('{{x,1},{0,1/eps}}', '{{1/x,-eps/x},{0,eps}}',
                          '{{{eps/x,0},{0,2 eps/(1-x)}}}')
        with tempfile.TemporaryDirectory() as temporary:
            retained = os.environ.get('CANON_TEST_OUTPUT_ROOT')
            work = Path(retained).resolve()/'final-backend-contract' if retained else Path(temporary)
            work.mkdir(parents=True, exist_ok=not bool(retained))
            package = work/'Fermatica-fixture.wl'
            package.write_text('BeginPackage["Fermatica`"];\n'
                'Fermatica`$FermaticaVersion="contract-fixture";Fermatica`$FermatVersionString="contract-fixture";\n'
                'Fermatica`FDot[a_,b_]:=Map[Together,a.b,{2}];\n'
                'Fermatica`FPlus[a__]:=Map[Together,Plus[a],{2}];\n'
                'Fermatica`FQuolyMod[a_,{}]:=a;EndPackage[];\n')
            executable = work/'unused-Fermat-fixture'
            executable.write_text('This contract fixture is never executed.\n')
            results = {}
            for name, updates, failed_gate in (
                    ('good', {}, None),
                    ('bad-basis', {'basis': [WL('j[1]'), WL('j[2]')]}, 'basis_definition'),
                    ('bad-gauge', {'matrices': WL('{{{eps/x,eps/x},{0,2 eps/(1-x)}}}')}, 'exact_global_gauge')):
                directory = work/name
                directory.mkdir()
                payload = {}
                for key, value in objects.items():
                    path = directory/(key+'.wl')
                    body = sealed({**value, **updates}) if key=='accepted_prefix' else value
                    path.write_text(wl(body)+'\n')
                    payload[key] = {'path': str(path)}
                payload['method_options'] = {'gauge_backend': 'fermat', 'package_entry': str(package)}
                request = directory/'input.json'
                request.write_text(json.dumps(dict(schema='canon-neu/script-input/v1', task_id=name,
                    step='FINAL_CHECK', sector=None, payload=payload)))
                p = subprocess.run([sys.executable, str(ROOT/'run_step.py'), '--defaults', str(request), str(directory/'check')],
                    env=dict(os.environ, CANON_WOLFRAMSCRIPT=RUNTIME, FERMATPATH=str(executable)),
                    capture_output=True, text=True, timeout=120)
                (directory/'process.log').write_text(p.stdout+p.stderr)
                result = json.loads((directory/'check/result.json').read_text())
                results[name] = result
                self.assertEqual(p.returncode, 0, result)
                self.assertEqual(result['code'], 'ALL_PASS' if failed_gate is None else 'FULL_SYSTEM_FAIL', result)
                if failed_gate:
                    self.assertFalse(result['summary']['checks'][failed_gate], result)
                else:
                    output = (directory/'check/canonical-de.wl').read_text()
                    self.assertIn('"fermat"', output)
                    self.assertIn(hashlib.sha256(package.read_bytes()).hexdigest(), output)
                    self.assertIn(hashlib.sha256(executable.read_bytes()).hexdigest(), output)
                if name=='bad-basis':
                    self.assertTrue(result['summary']['checks']['exact_global_gauge'], result)
            (work/'evidence.json').write_text(json.dumps(results, indent=2)+'\n')

    def test_exact_field_and_independent_failure_gates(self):
        rational = fixture('{{x,1},{0,1/eps}}', '{{1/x,-eps/x},{0,eps}}',
                           '{{{eps/x,0},{0,2 eps/(1-x)}}}')
        radical = fixture('{{Sqrt[x+y],1},{0,1/eps}}',
                          '{{1/Sqrt[x+y],-eps/Sqrt[x+y]},{0,eps}}',
                          '{{{eps/(x+y),0},{0,2 eps/(x+y)}},{{eps/(x+y),0},{0,2 eps/(x+y)}}}',
                          ('x', 'y'), ('x+y',))
        cases = [('rational-epsilon-pole', rational, True, None),
                 ('multivariable-radical', radical, True, None),
                 ('exact-root-number', fixture('{{Root[#^2-2&,2],0},{0,eps}}',
                     '{{1/Root[#^2-2&,2],0},{0,1/eps}}', '{{{eps/x,0},{0,eps/x}}}', alphabet=('x',)), True, None),
                 ('exact-complex-number', fixture('{{I,0},{0,1}}', '{{-I,0},{0,1}}',
                     '{{{eps/x,0},{0,eps/x}}}', alphabet=('x',)), True, None)]

        def changed(name, section, updates, gate, base=rational):
            value = copy.deepcopy(base)
            value[section].update(updates)
            cases.append((name, value, False, gate))

        changed('tampered-transformation', 'accepted_prefix',
                {'transformation': WL('{{2 x,1},{0,1/eps}}')}, 'basis_definition')
        changed('tampered-basis', 'accepted_prefix', {'basis': [WL('j[1]'), WL('j[2]')]}, 'basis_definition')
        changed('nonlinear-basis', 'accepted_prefix', {'basis': [WL('j[1]*j[2]'), WL('j[2]')]}, 'basis_definition')
        changed('inexact-basis', 'accepted_prefix',
                {'basis': WL('{1.0 (j[1]-eps j[2])/x,eps j[2]}')}, 'basis_definition')
        changed('singular-zero-residual-trap', 'accepted_prefix',
                {'transformation': WL('ConstantArray[0,{2,2}]'), 'basis': [0, 0]}, 'invertible_cumulative_transformation')
        changed('tampered-target-offdiagonal', 'accepted_prefix',
                {'matrices': WL('{{{eps/x,eps/x},{0,2 eps/(1-x)}}}')}, 'exact_global_gauge')
        original = rational['ordered_master_de']['matrices']
        changed('tampered-source-offdiagonal', 'ordered_master_de',
                {'matrices': WL('('+str(original)+')+{{{0,0},{1/x,0}}}')}, 'exact_global_gauge')
        changed('tampered-second-direction', 'accepted_prefix',
                {'matrices': WL('{{{eps/(x+y),0},{0,2 eps/(x+y)}},{{2 eps/(x+y),0},{0,2 eps/(x+y)}}}')},
                'exact_global_gauge', radical)
        changed('wrong-source-order', 'accepted_prefix', {'source_basis': [WL('j[2]'), WL('j[1]')]}, 'source_basis_resident_order')
        changed('wrong-identity', 'prepared_family', {'family_ref': 'other'}, 'artifact_identity')
        changed('incomplete-cursor', 'sector_manifest',
                {'sectors': [{'id': 1, 'propagator_count': 1}, {'id': 3, 'propagator_count': 2}]}, 'cursor_complete')
        changed('wrong-candidate-trace', 'accepted_prefix', {'candidate_trace': []}, 'candidate_trace_coverage')
        changed('wrong-trace', 'accepted_prefix', {'sector_trace': [{'id': 2, 'propagator_count': 1}]}, 'sector_trace_resident_order')
        changed('wrong-convention', 'accepted_prefix', {'convention': 'new=T.old'}, 'transformation_convention')
        changed('missing-letter', 'accepted_prefix', {'alphabet': [WL('x')]}, 'constant_residue_dlog')
        changed('regulator-in-letter', 'accepted_prefix', {'alphabet': [WL('eps*x'), WL('1-x')]}, 'epsilon_free_alphabet')
        wrong_hash = copy.deepcopy(rational)
        wrong_hash['accepted_prefix']['prefix_id'] = 'sha256:wrong'
        cases.append(('wrong-prefix-hash', wrong_hash, False, 'accepted_prefix_hash'))
        nonflat = fixture('{{1,0},{0,1}}', '{{1,0},{0,1}}',
            '{{{0,eps/x},{0,0}},{{0,0},{eps/y,0}}}', ('x', 'y'), ('x', 'y'))
        cases.append(('noncommuting-flatness', nonflat, False, 'flat_connection'))
        nonlinear_eps = fixture('{{1,0},{0,1}}', '{{1,0},{0,1}}',
            '{{{eps^2/x,0},{0,eps/x}}}', alphabet=('x',))
        cases.append(('nonlinear-epsilon', nonlinear_eps, False, 'epsilon_factorized'))

        with tempfile.TemporaryDirectory() as temporary:
            retained = os.environ.get('CANON_TEST_OUTPUT_ROOT')
            work = Path(retained).resolve()/'final-basis-witness' if retained else Path(temporary)
            work.mkdir(parents=True, exist_ok=not bool(retained))
            results = {}
            for name, objects, passing, failed_gate in cases:
                with self.subTest(case=name):
                    directory = work/name
                    directory.mkdir()
                    payload = {}
                    for key, value in objects.items():
                        path = directory/(key+'.wl')
                        body = sealed(value) if key=='accepted_prefix' and name!='wrong-prefix-hash' else value
                        path.write_text(wl(body)+'\n')
                        payload[key] = {'path': str(path)}
                    request = directory/'input.json'
                    request.write_text(json.dumps(dict(schema='canon-neu/script-input/v1', task_id=name,
                        step='FINAL_CHECK', sector=None, payload=payload)))
                    p = subprocess.run([sys.executable, str(ROOT/'run_step.py'), '--defaults', str(request),
                        str(directory/'check')], env=dict(os.environ, CANON_WOLFRAMSCRIPT=RUNTIME),
                        capture_output=True, text=True, timeout=120)
                    (directory/'process.log').write_text(p.stdout+p.stderr)
                    result = json.loads((directory/'check/result.json').read_text())
                    results[name] = result
                    (work/'evidence.json').write_text(json.dumps(results, indent=2)+'\n')
                    self.assertEqual(p.returncode, 0, result)
                    self.assertEqual((result['status'], result['code']),
                        ('PASS', 'ALL_PASS') if passing else ('FAIL', 'FULL_SYSTEM_FAIL'), result)
                    if passing:
                        self.assertTrue(all(result['summary']['checks'].values()), result)
                        self.assertEqual(set(result['artifacts']), {'canonical_basis', 'canonical_de'})
                    else:
                        self.assertFalse(result['summary']['checks'][failed_gate], result)
                        self.assertEqual(result['artifacts'], {})
                    print(name, result['status'], result['code'], flush=True)


if __name__ == '__main__':
    unittest.main(verbosity=2)
