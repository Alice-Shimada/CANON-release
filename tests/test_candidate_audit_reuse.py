"""File-bound candidate audit reuse through the existing public steps."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from test_reducer_bridge import FAMILY, MASTERS, CANDIDATES, DERIVATIVES, REDUCTION

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = os.environ.get('CANON_WOLFRAMSCRIPT') or shutil.which('wolframscript')


@unittest.skipUnless(RUNTIME, 'configure CANON_WOLFRAMSCRIPT')
class CandidateAuditReuseTests(unittest.TestCase):
    def test_file_binding_and_current_target_scope(self):
        with tempfile.TemporaryDirectory() as temporary:
            retained = os.environ.get('CANON_TEST_OUTPUT_ROOT')
            work = Path(retained).resolve() / 'candidate-audit-reuse' if retained else Path(temporary)
            work.mkdir(parents=True, exist_ok=not bool(retained))
            env = dict(os.environ, CANON_WOLFRAMSCRIPT=RUNTIME, CANON_PYTHON=sys.executable)
            results = {}

            def save(name, text):
                path = work / (name + '.wl')
                path.write_text(text + '\n')
                return {'path': str(path)}

            payload = {key: save(name, text) for key, name, text in (
                ('prepared_family', 'family', FAMILY), ('master_basis', 'masters', MASTERS),
                ('integral_candidates', 'candidates', CANDIDATES),
                ('prepared_derivatives', 'derivatives', DERIVATIVES))}
            payload['derivative_operator_selection'] = 'prepared-affine'
            reduction = save('rules', REDUCTION)
            contract = save('contract', '<|"schema"->"canon-neu/ibp-audit-contract/v1",'
                '"integral_head"->G,"index_count"->1,"coefficient_symbols"->{d,x},'
                '"expected_masters"->{G[1]},"required_targets"->{G[1],G[2]},"master_order"->"permutation"|>')

            def run(name, step, data, expected=('PASS', 'CANDIDATES_REDUCED')):
                request = work / (name + '.json')
                request.write_text(json.dumps(dict(schema='canon-neu/script-input/v1', task_id=name,
                    step=step, sector={'id': 1, 'propagator_count': 1}, payload=data)))
                process = subprocess.run([sys.executable, str(ROOT/'run_step.py'), '--defaults',
                    str(request), str(work/name)], env=env, capture_output=True, text=True, timeout=90)
                (work/(name+'.log')).write_text(process.stdout+process.stderr)
                result = json.loads((work/name/'result.json').read_text())
                results[name] = result
                (work/'evidence.json').write_text(json.dumps(results, indent=2)+'\n')
                self.assertEqual((result['status'], result['code']), expected, result)
                self.assertEqual(process.returncode, 0 if expected[0]=='PASS' else 1)
                print(name, result['status'], result['code'], flush=True)
                return result

            audited = run('audit', 'CHECK_IBP', {'ibp_reduction': reduction, 'ibp_contract': contract},
                          ('PASS', 'IBP_AUDIT_PASS'))
            receipt = {'path': str(work/'audit'/audited['artifacts']['ibp_audit']['path'])}
            plain = run('plain', 'REDUCE_CANDIDATE_IBP', {**payload, 'ibp_reduction': reduction})
            self.assertFalse(plain['summary']['ibp_audit']['reuse']['used'])
            reused = run('explicit', 'REDUCE_CANDIDATE_IBP',
                         {**payload, 'ibp_reduction': reduction, 'ibp_audit': receipt})
            self.assertTrue(reused['summary']['ibp_audit']['reuse']['used'])
            adjacent = Path(reduction['path']+'.audit.wl')
            adjacent.write_bytes(Path(receipt['path']).read_bytes())
            discovered = run('adjacent', 'REDUCE_CANDIDATE_IBP', {**payload, 'ibp_reduction': reduction})
            self.assertTrue(discovered['summary']['ibp_audit']['reuse']['used'])
            adjacent.unlink()
            changed = save('changed-rules', REDUCTION.replace('(1-d/2)', '(3-d/2)'))
            stale = run('stale', 'REDUCE_CANDIDATE_IBP',
                        {**payload, 'ibp_reduction': changed, 'ibp_audit': receipt})
            self.assertFalse(stale['summary']['ibp_audit']['reuse']['used'])
            rejected_receipt = save('nonpassing-receipt',
                'Join[Get['+json.dumps(receipt['path'])+'],<|"status"->"FAIL"|>]')
            reaudited = run('nonpassing', 'REDUCE_CANDIDATE_IBP',
                {**payload, 'ibp_reduction': reduction, 'ibp_audit': rejected_receipt})
            self.assertFalse(reaudited['summary']['ibp_audit']['reuse']['used'])
            old_hash = hashlib.sha256(Path(reduction['path']).read_bytes()).hexdigest()
            run('wrong-reduction-hash', 'REDUCE_CANDIDATE_IBP',
                {**payload, 'ibp_reduction': {**changed, 'sha256': old_hash}}, ('ERROR', 'SOURCE_HASH_MISMATCH'))
            run('wrong-receipt-hash', 'REDUCE_CANDIDATE_IBP',
                {**payload, 'ibp_reduction': reduction, 'ibp_audit': {**receipt, 'sha256': '0'*64}},
                ('ERROR', 'SOURCE_HASH_MISMATCH'))
            run('missing-receipt', 'REDUCE_CANDIDATE_IBP',
                {**payload, 'ibp_reduction': reduction, 'ibp_audit': {'path': str(work/'absent.wl')}},
                ('ERROR', 'MISSING_ARTIFACT'))
            changed_candidates = save('higher-candidates', CANDIDATES.replace('HoldComplete[G[1]]', 'HoldComplete[G[2]]'))
            uncovered = run('new-target', 'REDUCE_CANDIDATE_IBP',
                {**payload, 'integral_candidates': changed_candidates, 'ibp_reduction': reduction, 'ibp_audit': receipt},
                ('FAIL', 'IBP_CHECK_FAILED'))
            self.assertEqual(uncovered['summary']['reason_code'], 'IBP_MISSING_TARGETS')
            # A canonical large export takes the view before native Get. The
            # padding keeps this fixture independent of external research data.
            large_path = work/'large-rules.wl'
            with large_path.open('w') as stream:
                stream.write('<|"schema"->"canon-neu/ibp-reduction/v1",'
                    '"family_ref"->"bridge-fixture","basis_ref"->"source-basis",'
                    '"masters"->{G[1]},"rules"->{G[2]->(1-d/2)/x*G[1]')
                for index in range(3, 12):
                    stream.write(',G['+str(index)+']->')
                    for _ in range(8):
                        stream.write(' '*1024**2)
                    stream.write('0')
                stream.write('}|>\n')
            large = run('automatic-view', 'REDUCE_CANDIDATE_IBP',
                {**payload, 'ibp_reduction': {'path': str(large_path)}, 'ibp_audit': receipt})
            self.assertEqual(large['summary']['rules'], 1)
            self.assertFalse(large['summary']['ibp_audit']['reuse']['used'])
            self.assertLess((work/'automatic-view/ibp-rule-view.wl').stat().st_size, 1024)
            bridge_ref = {'path': str(work/'automatic-view'/large['artifacts']['candidate_ibp_bridge']['path'])}
            bound_receipt = {'path': str(work/'automatic-view'/large['artifacts']['ibp_audit']['path'])}
            downstream = run('view-downstream-audit', 'CHECK_IBP',
                {'ibp_reduction': bridge_ref, 'ibp_contract': contract, 'ibp_audit': bound_receipt},
                ('PASS', 'IBP_AUDIT_PASS'))
            self.assertTrue(downstream['summary']['reuse']['used'])
            gaussian = run('explicit-gaussian-field', 'REDUCE_CANDIDATE_IBP',
                {**payload, 'ibp_reduction': {'path': str(large_path)},
                 'ibp_audit_options': {'coefficient_field': 'Q(i)'}})
            self.assertEqual(gaussian['summary']['rules'], 10)
            self.assertFalse((work/'explicit-gaussian-field/ibp-rule-view-input.json').exists())
            fallback_path = work/'noncanonical-large-rules.wl'
            with fallback_path.open('w') as stream:
                for _ in range(65):
                    stream.write(' '*1024**2)
                stream.write(REDUCTION)
            fallback = run('unsupported-native-fallback', 'REDUCE_CANDIDATE_IBP',
                {**payload, 'ibp_reduction': {'path': str(fallback_path)}})
            self.assertEqual(fallback['summary']['rules'], 1)
            self.assertFalse((work/'unsupported-native-fallback/ibp-rule-view.wl').exists())
            # Mutate a separately bound receipt after it has been read. WL
            # disallows opening the source file itself for append during Get.
            changing = save('changing-rules',
                'With[{s=OpenAppend['+json.dumps(receipt['path'])+']},WriteString[s," "];Close[s]];\n'+REDUCTION)
            changed_input = run('changed-during-read', 'REDUCE_CANDIDATE_IBP',
                {**payload, 'ibp_reduction': changing, 'ibp_audit': receipt}, ('ERROR', 'IBP_EXECUTION_FAILED'))
            self.assertEqual(changed_input['summary']['reason_code'], 'IBP_AUDIT_INPUT_CHANGED')
            for name in results:
                self.assertFalse((work/name/'ibp-input.json').exists(), name)
                if name != 'audit' and results[name]['status'] != 'PASS':
                    self.assertNotIn('candidate_ibp_bridge', results[name]['artifacts'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
