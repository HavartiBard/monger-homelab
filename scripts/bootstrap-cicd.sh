#!/bin/bash
# Bootstrap CI/CD Infrastructure
# This script helps set up ArgoCD and Tekton on your K3s cluster

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
ARGOCD_VERSION="v2.9.3"
TEKTON_VERSION="v0.53.0"
ARGOCD_NAMESPACE="argocd"
TEKTON_NAMESPACE="tekton-pipelines"

# Functions
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    print_success "kubectl found"
    
    # Check if kubectl can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Check your KUBECONFIG."
        exit 1
    fi
    print_success "Connected to Kubernetes cluster"
    
    # Check if helm is installed
    if ! command -v helm &> /dev/null; then
        print_warning "helm not found. Some features will be limited."
    else
        print_success "helm found"
    fi
    
    # Display cluster info
    print_info "Cluster: $(kubectl config current-context)"
    print_info "Nodes: $(kubectl get nodes --no-headers | wc -l)"
}

install_argocd() {
    print_header "Installing ArgoCD"
    
    # Create namespace
    if kubectl get namespace "$ARGOCD_NAMESPACE" &> /dev/null; then
        print_warning "Namespace $ARGOCD_NAMESPACE already exists"
    else
        kubectl create namespace "$ARGOCD_NAMESPACE"
        print_success "Created namespace $ARGOCD_NAMESPACE"
    fi
    
    # Install ArgoCD
    print_info "Installing ArgoCD $ARGOCD_VERSION..."
    kubectl apply -n "$ARGOCD_NAMESPACE" -f "https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml"
    
    # Wait for ArgoCD to be ready
    print_info "Waiting for ArgoCD pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n "$ARGOCD_NAMESPACE" --timeout=300s
    
    print_success "ArgoCD installed successfully"
}

install_tekton() {
    print_header "Installing Tekton"
    
    # Install Tekton Pipelines
    print_info "Installing Tekton Pipelines $TEKTON_VERSION..."
    kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
    
    # Wait for Tekton to be ready
    print_info "Waiting for Tekton pods to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/part-of=tekton-pipelines -n "$TEKTON_NAMESPACE" --timeout=300s
    
    # Install Tekton Triggers
    print_info "Installing Tekton Triggers..."
    kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml
    kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml
    
    print_success "Tekton installed successfully"
}

install_tekton_tasks() {
    print_header "Installing Tekton Tasks"
    
    # Install git-clone task from catalog
    print_info "Installing git-clone task..."
    kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/git-clone/0.9/git-clone.yaml
    
    print_success "Tekton tasks installed"
}

deploy_custom_resources() {
    print_header "Deploying Custom Resources"
    
    # Get script directory
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    REPO_ROOT="$(dirname "$SCRIPT_DIR")"
    
    # Deploy Tekton tasks
    if [ -d "$REPO_ROOT/tekton/tasks" ]; then
        print_info "Deploying custom Tekton tasks..."
        kubectl apply -f "$REPO_ROOT/tekton/tasks/"
        print_success "Custom tasks deployed"
    fi
    
    # Deploy Tekton pipelines
    if [ -d "$REPO_ROOT/tekton/pipelines" ]; then
        print_info "Deploying Tekton pipelines..."
        kubectl apply -f "$REPO_ROOT/tekton/pipelines/"
        print_success "Pipelines deployed"
    fi
    
    # Deploy ArgoCD projects
    if [ -d "$REPO_ROOT/argocd/projects" ]; then
        print_info "Deploying ArgoCD projects..."
        kubectl apply -f "$REPO_ROOT/argocd/projects/"
        print_success "ArgoCD projects deployed"
    fi
    
    # Deploy ArgoCD applications
    if [ -d "$REPO_ROOT/argocd/applications" ]; then
        print_warning "ArgoCD applications found but not auto-deploying."
        print_info "Deploy manually with: kubectl apply -f argocd/applications/"
    fi
}

get_argocd_password() {
    print_header "ArgoCD Credentials"
    
    print_info "Getting initial admin password..."
    ARGOCD_PASSWORD=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
    
    echo -e "\n${GREEN}ArgoCD Login Credentials:${NC}"
    echo -e "  URL: ${BLUE}https://localhost:8080${NC} (after port-forward)"
    echo -e "  Username: ${BLUE}admin${NC}"
    echo -e "  Password: ${BLUE}$ARGOCD_PASSWORD${NC}"
    echo ""
    echo -e "${YELLOW}To access ArgoCD UI, run:${NC}"
    echo -e "  ${BLUE}kubectl port-forward svc/argocd-server -n argocd 8080:443${NC}"
    echo ""
}

install_argocd_cli() {
    print_header "Installing ArgoCD CLI (Optional)"
    
    if command -v argocd &> /dev/null; then
        print_success "ArgoCD CLI already installed"
        return
    fi
    
    print_info "Do you want to install ArgoCD CLI? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        print_info "Installing ArgoCD CLI..."
        curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        chmod +x /tmp/argocd
        sudo mv /tmp/argocd /usr/local/bin/argocd
        print_success "ArgoCD CLI installed"
    fi
}

install_tekton_cli() {
    print_header "Installing Tekton CLI (Optional)"
    
    if command -v tkn &> /dev/null; then
        print_success "Tekton CLI already installed"
        return
    fi
    
    print_info "Do you want to install Tekton CLI? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        print_info "Installing Tekton CLI..."
        TKN_VERSION="0.33.0"
        curl -LO "https://github.com/tektoncd/cli/releases/download/v${TKN_VERSION}/tkn_${TKN_VERSION}_Linux_x86_64.tar.gz"
        tar xvzf "tkn_${TKN_VERSION}_Linux_x86_64.tar.gz" tkn
        chmod +x tkn
        sudo mv tkn /usr/local/bin/
        rm "tkn_${TKN_VERSION}_Linux_x86_64.tar.gz"
        print_success "Tekton CLI installed"
    fi
}

show_next_steps() {
    print_header "Installation Complete! 🎉"
    
    echo -e "${GREEN}✅ ArgoCD installed in namespace: $ARGOCD_NAMESPACE${NC}"
    echo -e "${GREEN}✅ Tekton installed in namespace: $TEKTON_NAMESPACE${NC}"
    echo -e "${GREEN}✅ Custom resources deployed${NC}"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo ""
    echo -e "1. ${BLUE}Access ArgoCD UI:${NC}"
    echo -e "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo -e "   Then visit: https://localhost:8080"
    echo ""
    echo -e "2. ${BLUE}Access Tekton Dashboard (optional):${NC}"
    echo -e "   kubectl apply -f https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml"
    echo -e "   kubectl port-forward -n tekton-pipelines svc/tekton-dashboard 9097:9097"
    echo -e "   Then visit: http://localhost:9097"
    echo ""
    echo -e "3. ${BLUE}Test a pipeline:${NC}"
    echo -e "   tkn pipeline start infrastructure-validation -n tekton-pipelines --showlog"
    echo ""
    echo -e "4. ${BLUE}Deploy monitoring stack:${NC}"
    echo -e "   kubectl apply -f argocd/applications/monitoring-stack.yaml"
    echo ""
    echo -e "5. ${BLUE}Read the guides:${NC}"
    echo -e "   - docs/CI_CD_STRATEGY.md"
    echo -e "   - docs/IMPLEMENTATION_GUIDE.md"
    echo -e "   - CICD_README.md"
    echo ""
    echo -e "${GREEN}Happy GitOps-ing! 🚀${NC}"
}

# Main execution
main() {
    print_header "Monger Homelab CI/CD Bootstrap"
    
    check_prerequisites
    
    # Confirm before proceeding
    print_warning "This will install ArgoCD and Tekton on your cluster."
    print_info "Continue? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        print_info "Installation cancelled"
        exit 0
    fi
    
    install_argocd
    install_tekton
    install_tekton_tasks
    deploy_custom_resources
    get_argocd_password
    install_argocd_cli
    install_tekton_cli
    show_next_steps
}

# Run main function
main "$@"
