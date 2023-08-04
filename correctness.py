from pathlib import Path
import json

def main():
    result = dict()
    for fuzzer in ('fuzzilli', 'fuzzjit'):
        result[fuzzer] = dict()
        for engine in ('v8', 'sm', 'jsc'):
            rates = []
            base = Path('/storage/{}/{}'.format(fuzzer, engine))
            for p in base.glob('./*'):
                latest = 0
                latestPath = None
                for stats in p.glob('./stats/*'):
                    timestamp = int(stats.stem)
                    if timestamp > latest:
                        lastestPath = stats
                        latest = timestamp
                rates.append(json.load(stats.open())['correctnessRate'])

            avgRate = sum(rates) / len(rates)
            result[fuzzer][engine] = avgRate

    with open('/results/correctness.json', 'wt') as fd:
        json.dump(result, fd)

if __name__ == '__main__':
    main()
