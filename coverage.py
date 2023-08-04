import datetime
from pathlib import Path
import concurrent.futures
import subprocess
import tempfile
import json
import matplotlib.pyplot as plt
import numpy as np
import seaborn as sns
import pandas as pd
from pandas import DataFrame

ENGINEARGS = {
    'sm': ["--baseline-warmup-threshold=10",
           "--ion-warmup-threshold=100",
           "--ion-check-range-analysis",
           "--ion-extra-checks",
           "--fuzzing-safe"],
    'v8': ["--expose-gc",
           "--future",
           "--harmony",
           "--assert-types",
           "--harmony-rab-gsab",
           "--allow-natives-syntax",
           "--interrupt-budget=1000",
           "--fuzzing"],
    'jsc': ["--validateOptions=true",
            "--thresholdForJITSoon=10",
            "--thresholdForJITAfterWarmUp=10",
            "--thresholdForOptimizeAfterWarmUp=100",
            "--thresholdForOptimizeAfterLongWarmUp=100",
            "--thresholdForOptimizeSoon=100",
            "--thresholdForFTLOptimizeAfterWarmUp=1000",
            "--thresholdForFTLOptimizeSoon=1000",
            "--validateBCE=true"]
}

ENGINEPATH = {
    'v8': '/v8/out/coveragebuild/d8',
    'sm': '/gecko-dev/obj-covbuild/dist/bin/js',
    'jsc': '/webkit/CovBuild/Debug/bin/jsc'
}

LCOV = {
    'v8': '/v8/third_party/llvm-build/Release+Asserts/bin/llvm-cov',
    'sm': '/usr/bin/llvm-cov-13',
    'jsc': '/usr/bin/llvm-cov-13',
}

PROFDATA = {
    'v8': '/v8/third_party/llvm-build/Release+Asserts/bin/llvm-profdata',
    'sm': '/usr/bin/llvm-profdata-13',
    'jsc': '/usr/bin/llvm-profdata-13',
}

def compute_coverage(engine, run):
    jsfiles = list((datetime.datetime.strptime(p.stem.split('_')[1], '%Y%m%d%H%M%S'), p) for p in run.glob('./corpus/*.js'))
    jsfiles.sort()

    covered = [0]
    with tempfile.NamedTemporaryFile() as profraw, tempfile.NamedTemporaryFile() as profdata:
        start_time = jsfiles[0][0]
        for i in range(0, 144):
            beg = start_time + datetime.timedelta(seconds=600) * i
            end = start_time + datetime.timedelta(seconds=600) * (i + 1)
            chunk = [path for (timestamp, path) in jsfiles if beg <= timestamp < end]
            for path in chunk:
                try:
                    subprocess.run([ENGINEPATH[engine]] + ENGINEARGS[engine] + [path], timeout=5,
                                   env={"LLVM_PROFILE_FILE": profraw.name}, capture_output=True)
                except subprocess.TimeoutExpired:
                    continue
                subprocess.run([PROFDATA[engine], 'merge', '--num-threads=4', '-sparse', profraw.name, profdata.name, '-o', profdata.name])

            cmd = [LCOV[engine], 'export', '--num-threads=4', '--summary-only', ENGINEPATH[engine],
                   '-instr-profile={}'.format(profdata.name)]
            r = subprocess.run(cmd, capture_output=True)
            cov = json.loads(r.stdout)['data']
            assert(len(cov) == 1)
            branches = cov[0]['totals']['branches']['covered']
            covered.append(branches)

    return covered

def main():
    with concurrent.futures.ThreadPoolExecutor() as executor:
        future_to_org = {}
        for engine in ('sm', 'v8', 'jsc'):
            for fuzzer in ('fuzzilli', 'fuzzjit'):
                runs = Path('/storage/{}/{}'.format(fuzzer, engine))
                for idx, run in enumerate(runs.glob('./*')):
                    future = executor.submit(compute_coverage, engine, run)
                    future_to_org[future] = (fuzzer, idx, engine)

        j_results = {'fuzzilli': {'v8': [], 'jsc': [], 'sm': []},
                     'fuzzjit': {'v8': [], 'jsc': [], 'sm': []}}
        d_epoch = []
        d_coverage = []
        d_fuzzer = []
        d_engine = []
        d_engine_fuzzer = []
        for future in concurrent.futures.as_completed(future_to_org):
            fuzzer, idx, engine = future_to_org[future]
            coverage = future.result()
            j_results[fuzzer][engine].append(coverage)
            for idx, branches in enumerate(coverage):
                d_epoch.append(idx * 600)
                d_coverage.append(branches)
                d_fuzzer.append(fuzzer)
                d_engine.append(engine)
                d_engine_fuzzer.append('{}_{}'.format(engine, fuzzer))

        with open('/results/coverage.json', 'w') as fd:
            json.dump(j_results, fd)

        df = pd.DataFrame(data={'epoch': d_epoch,
                                'coverage': d_coverage,
                                'fuzzer': d_fuzzer,
                                'engine': d_engine,
                                'engine_fuzzer': d_engine_fuzzer})
        for engine in ('sm', 'v8', 'jsc'):
            subdf = df[df.engine == engine]
            ax = sns.lineplot(data=subdf, x='epoch', y='coverage', hue='fuzzer', ci=60)
            sns.despine()
            plt.savefig('/results/{}.svg'.format(engine))
            plt.close()

        ax = sns.lineplot(data=df, x='epoch', y='coverage', hue='engine_fuzzer', ci=60)
        sns.despine()
        plt.savefig('/results/all_engines.svg'.format(engine))
        plt.close()

if __name__ == '__main__':
    main()
