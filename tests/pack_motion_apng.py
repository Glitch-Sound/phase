"""Godotの実描画連番をAPNGへ可逆に格納し、全フレームのRGBAと時間を検証する。"""
import hashlib
import json
import struct
import sys
import zlib
from fractions import Fraction
from pathlib import Path

SIGNATURE = b'\x89PNG\r\n\x1a\n'

def chunks(data):
    assert data[:8] == SIGNATURE
    pos = 8
    while pos < len(data):
        size = struct.unpack_from('>I', data, pos)[0]
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + size]
        crc = struct.unpack_from('>I', data, pos + 8 + size)[0]
        assert zlib.crc32(kind + body) & 0xffffffff == crc
        yield kind, body
        pos += size + 12
    assert pos == len(data)

def chunk(kind, body):
    return struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body) & 0xffffffff)

def decode(width, height, data):
    packed = zlib.decompress(data)
    stride = width * 4
    assert len(packed) == height * (stride + 1)
    result = bytearray()
    prev = bytearray(stride)
    for y in range(height):
        pos = y * (stride + 1)
        mode = packed[pos]
        assert mode <= 4
        row = bytearray(packed[pos + 1:pos + 1 + stride])
        for x in range(stride):
            a = row[x - 4] if x >= 4 else 0
            b = prev[x]
            c = prev[x - 4] if x >= 4 else 0
            if mode == 1:
                predictor = a
            elif mode == 2:
                predictor = b
            elif mode == 3:
                predictor = (a + b) // 2
            elif mode == 4:
                p = a + b - c
                distances = (abs(p - a), abs(p - b), abs(p - c))
                predictor = (a, b, c)[distances.index(min(distances))]
            else:
                predictor = 0
            row[x] = (row[x] + predictor) & 255
        result.extend(row)
        prev = row
    return result

def pack(manifest_path, output):
    metadata = json.loads(manifest_path.read_text())
    rows = metadata['frames']
    assert len(rows) > 1 and not output.exists()
    first = list(chunks((manifest_path.parent / rows[0]['file']).read_bytes()))
    header = first[0][1]
    assert struct.unpack('>IIBBBBB', header) == (metadata['width'], metadata['height'], 8, 6, 0, 0, 0)
    result = bytearray(SIGNATURE + chunk(b'IHDR', header))
    for kind, body in first[1:]:
        if kind == b'IDAT':
            break
        result.extend(chunk(kind, body))
    result.extend(chunk(b'acTL', struct.pack('>II', len(rows), 1)))
    seq = 0
    delays = []
    for i, row in enumerate(rows):
        parts = list(chunks((manifest_path.parent / row['file']).read_bytes()))
        width, height, *fmt = struct.unpack('>IIBBBBB', parts[0][1])
        assert fmt == [8, 6, 0, 0, 0]
        assert row['x'] + width <= metadata['width'] and row['y'] + height <= metadata['height']
        delay = (rows[i + 1]['time'] - row['time']) if i + 1 < len(rows) else delays[-1]
        assert delay > 0
        delays.append(delay)
        fraction = Fraction(delay).limit_denominator(60000)
        assert 0 < fraction.numerator <= 65535 and fraction.denominator <= 65535
        result.extend(chunk(b'fcTL', struct.pack('>IIIIIHHBB', seq, width, height, row['x'], row['y'], fraction.numerator, fraction.denominator, 0, 0)))
        seq += 1
        compressed = b''.join(body for kind, body in parts if kind == b'IDAT')
        if i == 0:
            result.extend(chunk(b'IDAT', compressed))
        else:
            result.extend(chunk(b'fdAT', struct.pack('>I', seq) + compressed))
            seq += 1
    result.extend(chunk(b'IEND', b''))
    with output.open('xb') as stream:
        stream.write(result)
    # 出力を改めて読み、連番番号、時間、全画面RGBAを原寸の実描画ハッシュと照合する。
    canvas = bytearray(metadata['width'] * metadata['height'] * 4)
    control = None
    compressed = bytearray()
    index = 0
    sequence = 0
    duration = 0.0
    def verify_frame():
        nonlocal index, duration
        _, width, height, x, y, num, den, dispose, blend = control
        assert dispose == blend == 0
        rgba = decode(width, height, bytes(compressed))
        for line in range(height):
            dest = ((y + line) * metadata['width'] + x) * 4
            canvas[dest:dest + width * 4] = rgba[line * width * 4:(line + 1) * width * 4]
        assert hashlib.sha256(canvas).hexdigest() == rows[index]['sha256'], index
        assert abs(num / den - delays[index]) < 0.0001
        index += 1
        duration += num / den
    for kind, body in chunks(output.read_bytes()):
        if kind == b'acTL':
            assert struct.unpack('>II', body) == (len(rows), 1)
        elif kind == b'fcTL':
            if control is not None:
                verify_frame()
            control = struct.unpack('>IIIIIHHBB', body)
            assert control[0] == sequence
            sequence += 1
            compressed = bytearray()
        elif kind == b'IDAT':
            compressed.extend(body)
        elif kind == b'fdAT':
            assert struct.unpack_from('>I', body)[0] == sequence
            sequence += 1
            compressed.extend(body[4:])
    verify_frame()
    assert index == len(rows)
    summary = {'file': str(output.resolve()), 'frames': index, 'plays': 1, 'seconds': duration, 'bytes': output.stat().st_size, 'width': metadata['width'], 'height': metadata['height'], 'all_rgba_hashes_verified': True, 'min_delay': min(delays), 'max_delay': max(delays)}
    output.with_suffix('.verification.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps(summary))

if __name__ == '__main__':
    pack(Path(sys.argv[1]), Path(sys.argv[2]))
