#   Copyright (c) 2022 PaddlePaddle Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

from common_import import *


@benchmark_registry.register("transpose")
class TransposeConfig(APIConfig):
    def __init__(self):
        super(TransposeConfig, self).__init__("transpose")

    def init_from_json(self, filename, config_id=0, unknown_dim=16):
        super(TransposeConfig, self).init_from_json(filename, config_id,
                                                    unknown_dim)
        changed_dims = []
        for i in range(len(self.perm)):
            if self.perm[i] != i:
                changed_dims.append(i)

        if len(changed_dims) != 2:
            print(
                "Warning:\n"
                "  1. transpose is only supported to swap two dimensions in pytorch.\n"
            )
            self.run_torch = False
        else:
            self.dim0 = changed_dims[0]
            self.dim1 = changed_dims[1]


@benchmark_registry.register("transpose")
class PaddleTranspose(PaddleOpBenchmarkBase):
    def build_graph(self, config):
        x = self.variable(name='x', shape=config.x_shape, dtype=config.x_dtype)
        result = paddle.transpose(x, config.perm)

        self.feed_list = [x]
        self.fetch_list = [result]
        if config.backward:
            self.append_gradients(result, [x])

    def compute_flop_and_byte(self, config):
        x_shape = config.x_shape
        forward_flop = 0
        forward_byte = 2 * numel(x_shape) * sizeof(config.x_dtype)
        if not config.backward:
            return forward_flop, forward_byte
        else:
            # To be implemented.
            return None, None


@benchmark_registry.register("transpose")
class TorchTranspose(PytorchOpBenchmarkBase):
    def build_graph(self, config):
        x = self.variable(name='x', shape=config.x_shape, dtype=config.x_dtype)
        result = torch.transpose(input=x, dim0=config.dim0, dim1=config.dim1)

        self.feed_list = [x]
        self.fetch_list = [result]
        if config.backward:
            self.append_gradients(result, [x])


@benchmark_registry.register("transpose")
class TFTranspose(TensorflowOpBenchmarkBase):
    def build_graph(self, config):
        x = self.variable(name='x', shape=config.x_shape, dtype=config.x_dtype)
        result = tf.transpose(x, config.perm)

        self.feed_list = [x]
        self.fetch_list = [result]
        if config.backward:
            self.append_gradients(result, [x])
