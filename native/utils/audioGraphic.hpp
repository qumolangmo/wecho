#include "operator.hpp"

class AudioGraphic {
public:
    struct NodePort {
        int owner_id;
        int id;
        bool is_input;
        std::string name;

        NodePort(int owner_id, int id, bool is_input, const std::string& name)
            : owner_id(owner_id), id(id), is_input(is_input), name(name) {}
    };

    struct GraphicNode {
        int id;
        std::string name;

        std::unique_ptr<OperatorRoot> data;
        std::vector<NodePort> inputs;
        std::vector<NodePort> outputs;

        bool active;

        GraphicNode(int id, const std::string& name, bool active) noexcept
            : id(id), name(name), active(active) {}

        GraphicNode(GraphicNode&& other) noexcept
            : id(other.id), name(std::move(other.name)), active(other.active)
            , data(std::move(other.data)), inputs(std::move(other.inputs)), outputs(std::move(other.outputs)) {}

        GraphicNode& operator=(GraphicNode&& other) noexcept {
            if (&other != this) {
                id = other.id;
                name = std::move(other.name);
                data = std::move(other.data);
                inputs = std::move(other.inputs);
                outputs = std::move(other.outputs);
                active = other.active;
            }

            return *this;
        }

        GraphicNode(const GraphicNode&) = delete;
        GraphicNode& operator=(const GraphicNode&) = delete;
    };

    struct GraphicEdge {
        int id;
        int from_node;
        int from_port;
        int to_node;
        int to_port;
        bool active;

        GraphicEdge(int id, int from_node, int from_port, int to_node, int to_port, bool active)
            : id(id), from_node(from_node), from_port(from_port), to_node(to_node), to_port(to_port), active(active) {}
    };

    template<typename T>
    requires 
    std::is_same_v<T, OperatorType::RouterType>
    || std::is_same_v<T, OperatorType::EffectType>
    || std::is_same_v<T, OperatorType::AtomicComponentType>
    AudioGraphic& addNode(std::unique_ptr<OperatorRoot> node, bool active) {
        GraphicNode _node(node_id_counter, node->getName(), active);

        mapper[node->getName()] = node_id_counter;

        _node.data = std::move(node);

        nodes.emplace(node_id_counter, std::move(_node));

        node_id_counter++;
        return *this;
    }

    AudioGraphic& addConnection(const std::string& left, const std::string& right, int from_port, int to_port, bool active) {
        edges.emplace_back(GraphicEdge(edge_id_counter, mapper[left], from_port, mapper[right], to_port, active));

        edge_id_counter++;
        return *this;
    }

    void buildGraphic() {

    }

private:
    int node_id_counter = 0;
    int edge_id_counter = 0;
    std::unordered_map<std::string, int> mapper;
    std::unordered_map<int, GraphicNode> nodes;
    std::vector<GraphicEdge> edges;
    std::vector<int> process_chain;
    std::vector<int> inputs;
    std::vector<int> outputs;
};