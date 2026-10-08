#!/usr/bin/env python3
"""Comprueba la arquitectura PE de Windows y el paquete de recursos incrustado."""
import hashlib
import pathlib
import struct
import sys


def verify(path: pathlib.Path) -> dict:
    data = path.read_bytes()
    assert data[:2] == b"MZ", "Falta la cabecera ejecutable DOS/PE"
    pe_offset = struct.unpack_from("<I", data, 0x3C)[0]
    assert data[pe_offset:pe_offset + 4] == b"PE\0\0", "Falta la cabecera PE"
    machine = struct.unpack_from("<H", data, pe_offset + 4)[0]
    assert machine == 0x8664, f"El ejecutable no es Windows x86_64: {machine:x}"
    magic = struct.unpack_from("<H", data, pe_offset + 24)[0]
    assert magic == 0x20B, "El ejecutable no es PE32+ (64 bits)"
    # Godot termina su ejecutable con tamaño PCK (uint64 LE) y magic GDPC.
    assert data[-4:] == b"GDPC", "El ejecutable no contiene el paquete Godot incrustado"
    pck_size = struct.unpack_from("<Q", data, len(data) - 12)[0]
    pck_offset = len(data) - 12 - pck_size
    assert 0 < pck_offset < len(data), "Desplazamiento de paquete PCK inválido"
    assert data[pck_offset:pck_offset + 4] == b"GDPC", "Cabecera PCK inválida"
    assert pck_size > 256, "El paquete de recursos está vacío"
    return {"architecture": "Windows x86_64 / PE32+", "size": len(data),
            "pck_size": pck_size, "sha256": hashlib.sha256(data).hexdigest()}


if __name__ == "__main__":
    try:
        result = verify(pathlib.Path(sys.argv[1]))
    except (AssertionError, IndexError, OSError, struct.error) as error:
        raise SystemExit(f"Exportación inválida: {error}") from error
    for key, value in result.items():
        print(f"{key}: {value}")
    print("Esta comprobación estructural no ejecuta el juego en Windows.")
