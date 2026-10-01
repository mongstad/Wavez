"""Bounded standard-frame codecs; no optional import on the none path."""
MAX_CHUNK = 4*1024*1024
MAX_STORED = MAX_CHUNK+65536


def zstd_module():
    try:
        from compression import zstd
    except ImportError:
        try:
            from backports import zstd
        except ImportError as error:
            raise ValueError("Zstandard needs Python 3.14 compression.zstd or optional backports.zstd; use compression='none'") from error
    return zstd


def encode(raw, codec, level=1):
    if len(raw)>MAX_CHUNK: raise ValueError('Chunk exceeds 4 MiB ceiling')
    if codec==0: return raw
    if codec!=1: raise ValueError('Unsupported required codec')
    if not 1<=level<=6: raise ValueError('Zstandard level must be 1..6')
    z=zstd_module()
    return z.compress(raw,options={z.CompressionParameter.compression_level:level,
        z.CompressionParameter.window_log:22,z.CompressionParameter.content_size_flag:1,
        z.CompressionParameter.checksum_flag:1,z.CompressionParameter.nb_workers:0})


def validate_zstd_header(data, expected):
    if len(data)<6 or int.from_bytes(data[:4],'little')!=0xfd2fb528: raise ValueError('Invalid Zstandard header')
    descriptor=data[4];single=bool(descriptor&32);offset=5
    if descriptor&24: raise ValueError('Reserved Zstandard header bits')
    if not single:
        window=data[offset];offset+=1;base=1<<(10+(window>>3))
        if base+(base>>3)*(window&7)>MAX_CHUNK: raise ValueError('Zstandard window ceiling')
    dictionary_bytes=(0,1,2,4)[descriptor&3]
    if offset+dictionary_bytes>len(data) or any(data[offset:offset+dictionary_bytes]): raise ValueError('Unsupported Zstandard dictionary')
    offset+=dictionary_bytes
    count=(1 if single else 0,2,4,8)[descriptor>>6]
    if count==0 or offset+count>len(data): raise ValueError('Zstandard content size required')
    size=int.from_bytes(data[offset:offset+count],'little')+(256 if count==2 else 0)
    if size!=expected or (single and size>MAX_CHUNK): raise ValueError('Zstandard decoded size ceiling/mismatch')
    offset+=count
    while True:
        if offset+3>len(data): raise ValueError('Truncated Zstandard block')
        block=int.from_bytes(data[offset:offset+3],'little');offset+=3
        kind=(block>>1)&3;length=block>>3
        if kind==3 or length>128*1024: raise ValueError('Invalid Zstandard block')
        offset+=1 if kind==1 else length
        if offset>len(data): raise ValueError('Truncated Zstandard block')
        if block&1: break
    if descriptor&4: offset+=4
    if offset!=len(data): raise ValueError('Zstandard trailing data/checksum length')


def decode(stored, expected, codec):
    if not 0<=expected<=MAX_CHUNK or len(stored)>MAX_STORED:
        raise ValueError('Chunk allocation ceiling exceeded')
    if codec==0: result=stored
    elif codec==1:
        validate_zstd_header(stored,expected)
        z=zstd_module()
        decoder=z.ZstdDecompressor(options={z.DecompressionParameter.window_log_max:22})
        try: result=decoder.decompress(stored,expected+1)
        except z.ZstdError as error: raise ValueError("Invalid Zstandard payload") from error
        if not decoder.eof or decoder.unused_data: raise ValueError('Invalid Zstandard frame/decoded length')
    else: raise ValueError('Unsupported required codec')
    if len(result)!=expected: raise ValueError('Decoded chunk length mismatch')
    return result
