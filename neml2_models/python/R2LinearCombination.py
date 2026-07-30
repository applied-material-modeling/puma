from __future__ import annotations

from neml2.factory import register_neml2_object
from neml2.models.common.LinearCombination import _LinearCombination
from neml2.schema import HitSchema, output, var_inputs
from neml2.types import R2


@register_neml2_object("R2LinearCombination")
class R2LinearCombination(_LinearCombination):
    r"""Calculate linear combination of multiple R2 tensors as
    $u = w_i v_i + b$ (Einstein summation assumed), where $w_i$ are the weights
    and $v_i$ are the variables to be summed; $b$ is a constant offset.

    Python-native mirror of NEML2's C++ ``R2LinearCombination`` (same ``from`` /
    ``to`` / ``weights`` / ``offset`` schema). NEML2 3.0.7's python-native (AOTI)
    surface ships the ``Scalar`` and ``SR2`` variants (see
    ``neml2/models/common/LinearCombination.py``) but not the ``R2`` one, so
    models such as ``solidification_2d`` (``pk2 = pk2_e + pk2_sh``) cannot be
    ``neml2-compile``d without it.
    """

    _value_type = R2

    hit = HitSchema(
        var_inputs("from", R2, "R2 tensors to be summed", attr="_from_vars"),
        output("to", R2, "The sum", attr="_to"),
        *_LinearCombination._COMMON_PARAMETERS,
    )
